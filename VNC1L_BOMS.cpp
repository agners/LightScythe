/*
 VNC1L_BOMS by falstaff
 
 VNC1L_BOMS is a library to write on USB Flash Disk's using the FTDI's VNC1L 
 chip. BOMS means Bulk Only Mass Storage is a general description for USB Flash
 Disk's.
 
 Dependencies:
 - NewSoftSerial library
 
 created 10 July 2011
 by Stefan Agner

 http://falstaff.agner.ch/lightscythe/

*/

#include <WProgram.h>
#include <NewSoftSerial.h>
#include "VNC1L_BOMS.h"

VNC1L_BOMS::VNC1L_BOMS(int baud, byte pin_rx, byte pin_tx) {
  _vnc1l = NewSoftSerial(pin_rx, pin_tx);
  
  _vnc1l.begin(baud);
  
  
//  _vnc1l.print("IPA");
//  _vnc1l.print(13, BYTE);
}

void VNC1L_BOMS::sync() {
  // If there are no data yet, the VNC1L probably did not rebooted... Send a newline to get a prompt!
  if(!_vnc1l.available())
    _vnc1l.print(13, BYTE);
  // Waiting for initial prompt, show output on console...
  waitforprompt(true);
  
  // Switch to ASCII mode
  _vnc1l.print("IPA");
  _vnc1l.print(13, BYTE);
  waitforprompt();
  
  // Switching baudrate
  _vnc1l.print("SBD $");
  //_vnc1l.print(0x384100, HEX); // 9600
  //_vnc1l.print(0x9C8000, HEX); // 19200
  _vnc1l.print(0x4EC000, HEX); // 38400
  //_vnc1l.print(0x34C000, HEX); // 57600
  _vnc1l.print(13, BYTE);
  Serial.println("Switching baudrate to 57600");
  waitforprompt();
  delay(10);
  _vnc1l.begin(38400);
  delay(50);
  waitforprompt();
  Serial.println("Switching succeeded");
}

void VNC1L_BOMS::waitforprompt(boolean show)
{
  char msg[30];
  int i = 0;
  
  // Wait for prompt...
  while(true){
    if(_vnc1l.available())
    {
      msg[i] = _vnc1l.read();
      if(msg[i] == '\r')
      {
        msg[i] = 0;
        if(show)
          Serial.println(msg);
        if(msg[i-1] == '>')
          break;
        i = 0;
      }
      else
        i++;
    }
  }
}

void VNC1L_BOMS::file_open(const String &file) {
  _vnc1l.print("OPR ");
  _vnc1l.print(file);
  _vnc1l.print(13, BYTE);
  waitforprompt();
}

void VNC1L_BOMS::file_seek(long offset) {
  _vnc1l.print("SEK $");
  _vnc1l.print(offset, HEX);
  _vnc1l.print(13, BYTE);
  waitforprompt();
}

void VNC1L_BOMS::file_read(int count, byte buffer[]) {
  int done = 0;
  _vnc1l.print("RDF $");
  _vnc1l.print(count, HEX);
  _vnc1l.print(13, BYTE);
  
  while(done < count)
  {
    if(_vnc1l.available())
    {
      buffer[done] = _vnc1l.read();
      done++;
    }
  }
  waitforprompt();
}

void VNC1L_BOMS::file_close(const String &file) {
  _vnc1l.print("CLF ");
  _vnc1l.print(file);
  _vnc1l.print(13, BYTE);
}



