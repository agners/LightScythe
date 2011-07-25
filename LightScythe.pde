#include <multiCameraIrControl.h>

/*
 LightScythe by falstaff
 
 

 created 09 July 2011
 by Stefan Agner

 http://falstaff.agner.ch/lightscythe/

*/
#include "PushButton.h"
#include "VNC1L_BOMS.h"
#include "LEDStripe.h"

#define BAT_PIN 0
// Max voltage (according to Wikipedia 3x4.2V => 12.6V)
#define BAT_AD_MAX (1023 / 15.0 * 12.6)
#define BAT_WARNING 9.4
#define BAT_AD_MIN (1023 / 15.0 * BAT_WARNING)

#define NEXT_PIN 7
#define PREV_PIN 6
#define START_PIN 5
#define SHUTTER_PIN 8
#define POWER_PIN 9

#define LATCH_PIN 10

#define VDIP1_TX_PIN 2
#define VDIP1_RX_PIN 3
#define VDIP1_CTS_PIN 4
#define VDIP1_RTS_PIN 12

#define LED_COUNT 64
#define LED_BUFFER 192

#define DEBUG_PIN 13

#define MAX_PICTURE 9

#define _DEBUG 0

PushButton nextButton = PushButton((uint8_t)NEXT_PIN, 50, &next_pressed);
PushButton prevButton = PushButton((uint8_t)PREV_PIN, 50, &prev_pressed);
PushButton startButton = PushButton((uint8_t)START_PIN, 50, 3000, NULL, &start_pressed, &start_longup);

// LED stripe
HL1606stripPWM strip = HL1606stripPWM(64, LATCH_PIN);

// VDIP1 TX is our RX, and visa versa, baudrate try 38400 or 57600
VNC1L_BOMS flashDisk = VNC1L_BOMS(57600, VDIP1_TX_PIN, VDIP1_RX_PIN);

char filename[6] = "n.BMP";
long pic_offset; // Offset to the picture data inside the BMP file
long pic_width; // Width of the picture (=> This is going to be the height on the RGB LED's)
long pic_row_width; // Raw Width
long pic_height; // Height of the picture (=> This is going to be the width!)
int pic_bit_count;
static byte *pic_table;
static byte *pic_data;

// Nikon Shutter
Nikon D90(SHUTTER_PIN);

int picture_nbr = 0;

unsigned long clear_stripe_time;

void setup(){
  Serial.begin(57600);
  pinMode(DEBUG_PIN, OUTPUT);
  
  Serial.println("LightScythe starting...");
  
  // Initialize the buttons
  nextButton.setup();
  prevButton.setup();
  startButton.setup();
  
  // Initialize LED stripe
  strip.setSPIdivider(32);
  strip.begin();
  
  delay(1000);
  Serial.println("Syncing VDIP1...");
  flashDisk.sync();
  
  // Initialize the battery AD
  pinMode(BAT_PIN, INPUT);
  
  clear_stripe();
//  delay(3000);
//  Serial.println("Autostart...");
//  start_pressed();
}

void loop(){
  nextButton.check();
  prevButton.check();
  startButton.check();
  
  check_battery();
  
  if(clear_stripe_time != 0 && clear_stripe_time < millis()) {
    clear_stripe_time = 0;
    clear_stripe();
  }
}

void check_battery()
{
  int bat = analogRead(BAT_PIN);
  // Map AD value according to our voltage splitter (2K:1K => 10V:5V)
  bat = map(bat, 1, 1023, 0, 150);
  if(bat < BAT_WARNING * 10)
  {
    Serial.println("Warning, battery Low!!");
    show_battery();
  }
}

void next_pressed()
{
  if(picture_nbr < MAX_PICTURE)
    picture_nbr++;
  show_picture_nbr();
}
void prev_pressed()
{
  if(picture_nbr > 0)
    picture_nbr--;
  show_picture_nbr();
}

void show_picture_nbr() {
  Serial.print("Picture #");
  Serial.println(picture_nbr);
  for(int i = 0; i<=LED_COUNT;i++)
    strip.setLEDcolorPWM(i, 0, 0, i == picture_nbr ? 0xFF : 0);
  strip.writeStripe();
  
  // Clear stripe after 5 seconds
  clear_stripe_time = millis() + 5000;
}

void start_longup() {
  // Show battery state
  show_battery();
  
  // Show 5 seconds
  clear_stripe_time = millis() + 5000;
}

void show_battery() {
  // Show battery state...
  int bat = analogRead(BAT_PIN);
  bat = map(bat, BAT_AD_MIN, BAT_AD_MAX, 0, LED_COUNT);
  // Show column
  for(int i = 0; i<LED_COUNT;i++) {
    if(i<bat)
    {
      if(i < 8) // First 8 LED's red...
        strip.setLEDcolorPWM(LED_COUNT-i, 0xFF, 0, 0);
      else if(i < 24) // Next 16 LED's yellow...
        strip.setLEDcolorPWM(LED_COUNT-i, 0xFF, 0xFF, 0);
      else // The rest is green
        strip.setLEDcolorPWM(LED_COUNT-i, 0, 0xFF, 0);
    }
    else
        strip.setLEDcolorPWM(i-LED_COUNT, 0, 0, 0);
  }
  strip.writeStripe();
}

void start_pressed() {
  // Clear the stripe...
  clear_stripe();
  
  // Fire our shutter, twice!
  Serial.println("Fire shutter...");
  D90.shutterNow();
  delay(50);
  D90.shutterNow();
  delay(500);
  
  
  // Set picture number for file open string...
  filename[0] = '0' + picture_nbr;
  
  // Open the file
  Serial.print("Open file: ");
  Serial.println(filename);
  flashDisk.file_open(filename);
  
  // Get the offset to the picture data
  flashDisk.file_seek(0xA);
  flashDisk.file_read(4, (byte*)&pic_offset);
  // Get picture width
  flashDisk.file_seek(0x12);
  flashDisk.file_read(4, (byte*)&pic_width);
  // Get picture height
  flashDisk.file_seek(0x16);
  flashDisk.file_read(4, (byte*)&pic_height);
  // Bit depth hast to be 8!
  flashDisk.file_seek(0x1C);
  flashDisk.file_read(2, (byte*)&pic_bit_count);
  
  // We only support 8-Bit and 4-Bit indexed BMP files
  if(pic_bit_count != 8 && pic_bit_count != 4)
  {
    error_stripe();
    Serial.print("Bit count is ");
    Serial.print(pic_bit_count);
    Serial.println("! Make sure you saved the file as a 4/8-Bit Bitmap.");
    delay(500);
    clear_stripe();
    flashDisk.file_close(filename);
    return;
  }
  
  // Get count of colors in picture table
  long pic_table_entries;
  flashDisk.file_seek(0x2E);
  flashDisk.file_read(4, (byte*)&pic_table_entries);
  
  // Calculate a BMP row width in bytes. This is allways a multiple of 4
  pic_row_width = (pic_width * 3);
  int uneven_bytes = pic_row_width % 4;
  if(uneven_bytes)
    pic_row_width += 4 - uneven_bytes;
  
  
  Serial.print("Picture Offset: ");
  Serial.println(pic_offset);
  Serial.print("Picture Columns: ");
  Serial.println(pic_height);
  Serial.print("Picture Rows: ");
  Serial.println(pic_width);
  Serial.print("Picture Depth (bit): ");
  Serial.println(pic_bit_count);
  Serial.print("Picture Colors: ");
  Serial.println(pic_table_entries);
  
  // Seek to color table (we ignore color masks, should not be there!)
  pic_table = (byte*)malloc(pic_table_entries*3);
  // This is going to be a seek/read party, because we don't want the unused bytes laying around... (B.G.R.X)
  // Saves us up to 256 bytes!
  for(int offset = 0;offset<pic_table_entries;offset++)
  {
    flashDisk.file_seek(0x36 + offset*4);
    flashDisk.file_read(3, pic_table + offset*3);
#if _DEBUG
    Serial.print("Color ");
    Serial.print(offset);
    Serial.print(":");
    Serial.print(*(pic_table + offset*3), HEX);
    Serial.print(*(pic_table + offset*3+1), HEX);
    Serial.println(*(pic_table + offset*3+2), HEX);
#endif
  }
  
  // Calculate row size and allocate memory for the data...
  int rowsize = (pic_bit_count * pic_width / 32) * 4;
  Serial.print("Calculated rowsize: ");
  Serial.println(rowsize);
  pic_data = (byte*)malloc(rowsize);
  
  // Go to start of picture
  Serial.println("Seeking to picture data...");
  flashDisk.file_seek(pic_offset);
  
  // Column's are the BMP's rows...
  int column = 0;
  int index;
  unsigned long showmillis;
  
  // Read first column...
  Serial.println("Starting to display the picture...");
  flashDisk.file_read(rowsize, pic_data);
  for(column = 1; column < pic_height; column++)
  {
    // Show column
    if(pic_bit_count == 4)
    {
      // We need to write two LED's at once
      for(int i = 0; i<LED_COUNT/2;i++)
      {
        // Get the upper 4-Bit index to the color palette
        index = *(pic_data + i) >> 4;
        strip.setLEDcolorPWM(i*2, pic_table[index * 3 + 2], pic_table[index * 3 + 1], pic_table[index * 3 + 0]);
        // Get the lower 4-Bit index to the color palette
        index = *(pic_data + i) & 0x0F;
        strip.setLEDcolorPWM(i*2+1, pic_table[index * 3 + 2], pic_table[index * 3 + 1], pic_table[index * 3 + 0]);
      }
    }
    else if(pic_bit_count == 8)
    {
      // Write LED by LED
      for(int i = 0; i<LED_COUNT;i++)
      {
        // Get 8-Bit index to the color palette
        index = *(pic_data + i);
        // Using the color index
        strip.setLEDcolorPWM(i, pic_table[index * 3 + 2], pic_table[index * 3 + 1], pic_table[index * 3 + 0]);
      }
      
    }
    strip.writeStripe();
    showmillis = millis();
    
    // We show the led for at least 30ms
    while((millis() - showmillis) < 30);
    
    clear_stripe();
    
    showmillis = millis();
    
    // While dark, read the next column...
    unsigned long  t = millis();
    flashDisk.file_read(rowsize, pic_data);
    
    
    // We show nothing for another 30ms
    while((millis() - showmillis) < 30);
    //Serial.println(millis() - t);
    
    if(startButton.pressed())
    {
      // Wait for release... 
      while(!startButton.pressed());
      break;
    }
  }
  
  flashDisk.file_close(filename);
  free(pic_table);
  free(pic_data);
  
  Serial.println("End");
}



void clear_stripe() {
  for(int i = 0; i<LED_COUNT;i++)
    strip.setLEDcolorPWM(i, 0, 0, 0);
  strip.writeStripe();
}

void error_stripe() {
  for(int i = 0; i<LED_COUNT;i++)
    strip.setLEDcolorPWM(i, 255, 0, 0);
  strip.writeStripe();
}

