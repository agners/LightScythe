/*
 LightScythe by falstaff
 
 

 created 09 July 2011
 by Stefan Agner

 http://falstaff.agner.ch/lightscythe/

*/

#include "PushButton.h"
#include "VNC1L_BOMS.h"
#include <NewSoftSerial.h>

#define BAT_PIN 0

#define NEXT_PIN 7
#define PREV_PIN 6
#define START_PIN 5
#define SHUTTER_PIN 8
#define POWER_PIN 9

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
PushButton startButton = PushButton((uint8_t)START_PIN, 50, &start_pressed);

// VDIP1 TX is our RX, and visa versa
VNC1L_BOMS flashDisk = VNC1L_BOMS(9600, VDIP1_TX_PIN, VDIP1_RX_PIN);
char filename[6] = "n.bmp";
long pic_offset = 0; // Offset to the picture data inside the BMP file
long pic_width = 0; // Width of the picture (=> This is going to be the height on the RGB LED's)
long pic_row_width = 0; // Raw Width
long pic_height = 0; // Height of the picture (=> This is going to be the width!)

byte led_data[LED_COUNT*3];

int pictureNbr;

void setup(){
  Serial.begin(57600);
  pinMode(DEBUG_PIN, OUTPUT);
  
  // Initialize the buttons
  nextButton.setup();
  prevButton.setup();
  startButton.setup();
  
  // Initialize the battery AD
  pinMode(BAT_PIN, INPUT);
}

void loop(){
  nextButton.check();
  prevButton.check();
  startButton.check();
  
  check_battery();
  
}

void check_battery()
{
  
}

void next_pressed()
{
  if(pictureNbr < MAX_PICTURE)
    pictureNbr++;
}
void prev_pressed()
{
  if(pictureNbr > 0)
    pictureNbr--;
}

void start_pressed()
{
  // Set picture number for file open string...
  filename[0] = '0' + pictureNbr;
  
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
  
  
  Serial.print("Picture Columns: ");
  Serial.print(pic_height);
  Serial.print("Rows: ");
  Serial.print(pic_width);
  Serial.println();
  
  // Column's are the BMP's rows...
  int column;
  for(column = 0; column < pic_height; column++)
  {
    // Show the current row..
    show_picture_row(column);
    // 20ms delay between each row...
    delay(20);
  }
  
  
  Serial.println("End");
}

void show_picture_row(int column) {
  long row_offset = pic_offset;
  
  // If height is negativ, its a buttom up picture, get last row first...
  if(pic_height < 0)
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
  
  // Read the line
  flashDisk.file_read(LED_COUNT * 3, led_data);
  
  // Display it on the LightScythe
  // TODO
  
}

