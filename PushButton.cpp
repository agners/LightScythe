/*
 PushButton by falstaff
 
 PushButton is a class to debounce a button. It's using active low, means pressed is 0V.
 Based on David A. Mellis and Limor Fried debounce sample.
 
 created 09 July 2011
 by Stefan Agner

 http://falstaff.agner.ch/lightscythe/

*/

#include "PushButton.h"

PushButton::PushButton(byte pin, long debounceDelay, void (*pressed)(void)) {
  _pin = pin;
  _debounceDelay = debounceDelay;
  _pressed = pressed;
}

void PushButton::setup()
{
  pinMode(_pin, INPUT);
  // Enable pull up resistors
  digitalWrite(_pin, HIGH);
}

void PushButton::check() {
  uint8_t newState;
  
  // Get the new state from the pin
  newState = digitalRead(_pin);
  
  // Button state changed?
  if(newState != _lastState)
    _lastDebounceTime = millis();
    
  // Is the debounce delay reached and is it a new state at all?
  if ((millis() - _lastDebounceTime) > _debounceDelay && _state != newState) {
    // The new state exceeded the debounce delay, take it as the actual statue
    _state = newState;
    // 0 == active, generate a press event
    if(_state == 0)
      _pressed();
  }
    
  // Save the state...
  _lastState = newState;
}
