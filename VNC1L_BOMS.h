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

#ifndef VNC1L_BOMS_h
#define VNC1L_BOMS_h

#include "WProgram.h"
#include "SoftwareSerial.h"

class VNC1L_BOMS
{
  private:
    SoftwareSerial _vnc1l;
    byte _pin_rx;
    byte _pin_tx;
    long _baud;
    boolean waitforprompt(boolean show=false);
    
  public:
    VNC1L_BOMS(long baud, byte pin_rx, byte pin_tx);
    boolean file_open(const String &file);
    boolean file_seek(long offset);
    void file_read(int count, byte[]);
    void file_close(const String &file);
    void sync();
};

#endif


