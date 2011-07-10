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

VNC1L_BOMS::VNC1L_BOMS(int baud, byte pin_rx, byte pin_tx, byte pin_cts, byte pin_rts) {
  _vnc1l = NewSoftSerial(pin_rx, pin_tx);
  _pin_cts = pin_cts;
  _pin_rts = pin_rts;
  
  _vnc1l.begin(baud);
}

void VNC1L_BOMS::file_open(const String &file) {
  _vnc1l.print("OPR ");
  _vnc1l.print(file);
  _vnc1l.print(13, BYTE);
}

void VNC1L_BOMS::file_seek(long offset) {
  _vnc1l.print("SEK ");
  _vnc1l.print(offset);
  _vnc1l.print(13, BYTE);
}

void VNC1L_BOMS::file_read(int count, byte buffer[]) {
  int done = 0;
  _vnc1l.print("RDF ");
  _vnc1l.print(count);
  _vnc1l.print(13, BYTE);
  
  while(done < count)
  {
    if(_vnc1l.available())
    {
      buffer[done] = _vnc1l.read();
      done++;
    }
  }
}

void VNC1L_BOMS::file_close(const String &file) {
  _vnc1l.print("CLF ");
  _vnc1l.print(file);
  _vnc1l.print(13, BYTE);
}



