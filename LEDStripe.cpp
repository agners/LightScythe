// Written from scratch, but inspired by 
// http://waitingforbigo.com/2010/10/02/second-preview-release-of-fastspi_led-library
// This library can PWM an HL1606 strip with 3 or 4 bits of color per LED
// See the example sketches for more detailed usage

// (c) Adafruit Industries / Limor Fried 2010. Released under MIT license.

#include <inttypes.h>
#include "LEDStripe.h"

// the arrays of bytes that hold each LED's PWM values
static uint8_t *redPWM;
static uint8_t *greenPWM;
static uint8_t *bluePWM;

// how many LEDs
static uint8_t nLEDs;

// the latch pin
static uint8_t latchPin;




HL1606stripPWM::HL1606stripPWM(uint8_t n, uint8_t l) {
  nLEDs = n;
  latchPin = l;
  
  SPIspeedDiv = 32;

  redPWM = (uint8_t *)malloc(nLEDs);
  greenPWM = (uint8_t *)malloc(nLEDs);
  bluePWM = (uint8_t *)malloc(nLEDs);
  for (uint8_t i=0; i< nLEDs; i++) {
    setLEDcolorPWM(i, 0, 0, 0);
  }
}

void HL1606stripPWM::begin(void) {
  SPIinit();
}



void HL1606stripPWM::setLEDcolorPWM(uint8_t n, uint8_t r, uint8_t g, uint8_t b) {
     redPWM[n] = r; 
     greenPWM[n] = g; 
     bluePWM[n] = b;
}


void HL1606stripPWM::writeStripe() {
  uint8_t i, d;
  
  // write out data to strip 
  for (i=0; i< nLEDs; i++) {
    d = 0x80;          // set the latch bit
    
    // calculate the next LED's byte
    if (127 < redPWM[i]) {
      d |= 0x04;
    } 
    if (127 < greenPWM[i]) {
      d |= 0x10;
    } 
    if (127 < bluePWM[i]) {
      d |= 0x01;
    } 

    // check that previous xfer completed
    while(!(SPSR & _BV(SPIF))); 
 
    // send new data
    SPDR = d; 
  }

  // make sure we're all done
  while(!(SPSR & _BV(SPIF)));

  // latch
  digitalWrite(latchPin, HIGH);
  delayMicroseconds(3);
  digitalWrite(latchPin, LOW);
}


void HL1606stripPWM::SPIinit(void) {
  pinMode(DATA_PIN, OUTPUT);
  pinMode(CLOCK_PIN, OUTPUT);
  pinMode(latchPin, OUTPUT);
  
  // set up high speed SPI for 500 KHz
  // The datasheet says that the clock pulse width must be > 300ns. Two pulses > 600ns that would
  // make the max frequency 1.6 MHz - fat chance getting that out of HL1606's though
  SPCR = _BV(SPE) | _BV(MSTR);   // enable SPI master mode
  setSPIdivider(SPIspeedDiv);          // SPI clock is FCPU/32 = 500 Khz for most arduinos
  
  // we send a fake SPI byte to get the 'finished' bit set in the register, dont remove!!!
  SPDR = 0;
}

uint8_t HL1606stripPWM::getSPIdivider(void) { return SPIspeedDiv; }

void HL1606stripPWM::setSPIdivider(uint8_t spispeed) {
  SPIspeedDiv = spispeed;

  switch (spispeed) {
    case 2:
      SPSR |= _BV(SPI2X);
      break;
    case 4:
      // no bits set
      break;
    case 8:
      SPCR |= _BV(SPR0); 
      SPSR |= _BV(SPI2X);
      break;
    case 16:
      SPCR |= _BV(SPR0); 
      break;
    case 32:
      SPCR |= _BV(SPR1); 
      SPSR |= _BV(SPI2X);
      break;
    case 64:
      SPCR |= _BV(SPR1); 
      break;
    default:      // slowest
    case 128:
      SPCR |= _BV(SPR1);
      SPCR |= _BV(SPR0);  
  }

}

uint8_t HL1606stripPWM::numLEDs(void) {
  return nLEDs;
}

