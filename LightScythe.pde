/*
 LightScythe by falstaff
 
 

 created 09 July 2011
 by Stefan Agner

 http://falstaff.agner.ch/lightscythe/

*/

#include <NewSoftSerial.h>
#include "PushButton.h"
#include "VNC1L_BOMS.h"
#include "LEDStripe.h"

#define BAT_PIN 0
#define BAT_AD_MAX (1023 / 15.0 * 12.6)

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

PushButton nextButton = PushButton((uint8_t)NEXT_PIN, 50, &next_pressed);
PushButton prevButton = PushButton((uint8_t)PREV_PIN, 50, &prev_pressed);
PushButton startButton = PushButton((uint8_t)START_PIN, 50, 3000, NULL, &start_pressed, &start_longup);

// LED stripe
HL1606stripPWM strip = HL1606stripPWM(64, LATCH_PIN);

// VDIP1 TX is our RX, and visa versa
VNC1L_BOMS flashDisk = VNC1L_BOMS(9600, VDIP1_TX_PIN, VDIP1_RX_PIN);
char filename[6] = "n.BMP";
long pic_offset; // Offset to the picture data inside the BMP file
long pic_width; // Width of the picture (=> This is going to be the height on the RGB LED's)
long pic_row_width; // Raw Width
long pic_height; // Height of the picture (=> This is going to be the width!)

byte led_data[LED_COUNT*3];

int picture_nbr = 2;
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
  Serial.println("Battery voltage: ");
  Serial.println(check_battery() / 10.0, 1);
  
  delay(3000);
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

int check_battery()
{
  int bat = analogRead(BAT_PIN);
  bat = map(bat, 1, BAT_AD_MAX, 0, 150);
  if(bat < 90)
    Serial.println("Warning, battery Low!!");
  return bat;
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
  int bat = analogRead(BAT_PIN);
  bat = map(bat, 1, 1023, 0, LED_COUNT);
  // Show column
  for(int i = 0; i<=bat;i++) {
    if(i < 8) // First 8 LED's red...
      strip.setLEDcolorPWM(i, 0xFF, 0, 0);
    else if(i < 24) // Next 16 LED's yellow...
      strip.setLEDcolorPWM(i, 0xFF, 0xFF, 0);
    else // The rest is green
      strip.setLEDcolorPWM(i, 0, 0xFF, 0);
  }
  strip.writeStripe();
  
  // Show 5 seconds
  clear_stripe_time = millis() + 5000;
}

void start_pressed() {
  // Set picture number for file open string...
  filename[0] = '0' + picture_nbr;
  
  Serial.print("Start: ");
  Serial.println(filename);
  
  // Open the file
  flashDisk.file_open(filename);
  
  // We do support 24-bit BMP
  // Get the offset for the picture data
  flashDisk.file_seek(0xA);
  flashDisk.file_read(4, (byte*)&pic_offset);
  // Get file width
  flashDisk.file_seek(0x12);
  flashDisk.file_read(4, (byte*)&pic_width);
  // Get file height
  flashDisk.file_seek(0x16);
  flashDisk.file_read(4, (byte*)&pic_height);
  
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
  
  flashDisk.file_seek(pic_offset);
  
  // Column's are the BMP's rows...
  int column = 0;
  
  // Read first column...
  show_picture_row(column);
  for(column = 1; column < pic_height; column++)
  {
    // Show column
    for(int i = 0; i<LED_COUNT;i++)
      strip.setLEDcolorPWM(i, led_data[i*3+2], led_data[i*3+1], led_data[i*3+0]);
    strip.writeStripe();
    
    // Read next column...
    show_picture_row(column);
    /*
    delay(20);
    */
  }
  
  flashDisk.file_close(filename);
  
  Serial.println("End");
}
void clear_stripe() {
  for(int i = 0; i<LED_COUNT;i++)
    strip.setLEDcolorPWM(i, 0, 0, 0);
  strip.writeStripe();
}

void show_picture_row(int column) {
  long row_offset = pic_offset;
  
  // If height is negativ, its a buttom up picture, get last row first...
  /*
  if(pic_height > 0)
  {
    // Buttom up picture
    row_offset += pic_row_width * (pic_height - 1); // => Start of last row
    row_offset -= pic_row_width * column;
  }
  else
  {
    // Top down picture
    row_offset += pic_row_width * column;
  }
  
  // Seek to the start of the line
  flashDisk.file_seek(row_offset);
  */
  // Read the line
  unsigned long t = millis();
  flashDisk.file_read(LED_COUNT * 3, led_data);
  Serial.print("T=");
  Serial.println(millis() - t);
  
  
  // Display it on the LightScythe
  /*
  Serial.print("Column: ");
  Serial.print(led_data[0], HEX);
  Serial.print(led_data[1], HEX);
  Serial.println(led_data[2], HEX);
  */
  // TODO
  
}

