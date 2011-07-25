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
    byte _longState;
    byte _lastState;
    long _lastDebounceTime;
    long _debounceDelay;
    long _pressTime;
    long _longPressDelay;
    boolean _wasLongPress;
    void (*_pressed)(void);
    void (*_released)(void);
    void (*_longreleased)(void);
    void init();
  public:
    PushButton(byte pin, long debounceDelay, void (*pressed)(void));
    PushButton(byte pin, long debounceDelay, long longPressDelay, void (*pressed)(void), void (*released)(void), void (*longreleased)(void));
    byte pressed();
    void setup();
    void check();
};

#endif
