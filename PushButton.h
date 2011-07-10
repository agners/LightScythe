/*
 PushButton by falstaff
 
 PushButton is a class to debounce a button. It's using active low, means pressed is 0V.
 Based on David A. Mellis and Limor Fried debounce sample.

 created 09 July 2011
 by Stefan Agner

 http://falstaff.agner.ch/lightscythe/

*/


#ifndef PushButton_h
#define PushButton_h

#include "WProgram.h"

class PushButton
{
  private:
    byte _pin;
    byte _state;
    byte _lastState;
    long _lastDebounceTime;
    long _debounceDelay;
    void (*_pressed)(void);
  public:
    PushButton(uint8_t, long, void (*pressed)(void));
    void setup();
    void check();
};

#endif
