/************************************************************
                    TESIS DE GRADO
                       EEG v2.0
            Instituto de Ingeniería Biomédica
    Facultad de Ingenieria, Universidad de Buenos Aires

                   Florencia Grosso
                  Tutor: Sergio Lew

  Code description:
  This code controls the IC ADS1299 through an Arduino NANO.
  It handles the startup sequence (configuration, setup) of
  the device and triggers the data conversion.
  The processing loop reads data continuously, processes it
  and sends it to a computer through SPI.
*************************************************************/

// Libraries
#include <SPI.h>

// Clock
#define tCLK 0.0005 // 2 MHz, 500 ns

// Commands
// System commands
#define WAKEUP 0x02
#define STANDBY 0x04
#define RESET 0x06
#define START 0x08
#define STOP 0x0A

// Data Read Commands
// Read Data Continuous mode
#define RDATAC 0x10
// Stop Read Data Continuously mode
#define SDATAC 0x11
//Read data by command 
#define RDATA 0x12 

// Register Read Commands
#define RREG 0x20
#define WREG 0x40

// Registers
#define ID 0x00
#define CONFIG1 0x01
#define CONFIG2 0x02
#define CONFIG3 0x03
#define LOFF 0x04
#define CH1SET 0x05
#define CH2SET 0x06
#define CH3SET 0x07
#define CH4SET 0x08
#define CH5SET 0x09
#define CH6SET 0x0A
#define CH7SET 0x0B
#define CH8SET 0x0C
#define BIAS_SENSP 0x0D
#define BIAS_SENSN 0x0E
#define LOFF_SENSP 0x0F
#define LOFF_SENSN 0x10
#define LOFF_FLIP 0x11
#define LOFF_STATP 0x12
#define LOFF_STATN 0x13
#define GPIO 0x14
#define MISC1 0x15
#define MISC2 0x16
#define CONFIG4 0x17

// Pins for the arduino board
const int PIN_DRDY = 2;
const int PIN_START = 5;
const int PIN_SS = 10;
const int PIN_MOSI = 11; // DIN
const int PIN_MISO = 12; // DOUT
const int PIN_SCK = 13;
const int PIN_RESET = 4;

// Prototypes of used functions
void wake_up();
void send_command(uint8_t command);
void send_command_and_wait(uint8_t command, float time_to_wait);
byte fRREG(byte address);
void fWREG(byte address, byte data);
void get_device_id();

// Global variables
// Flag that indicates whether debug logs should be published
boolean verbose = false;
// Device id published by the ADS1299
byte device_id = 0;
// Number of active EEG channels
unsigned int active_channels = 2;

void setup() {
  /* Initialization routine for SPI bus */
  // Initalize communication with computer.
  // Open serial port (USB), max rate 115bps
  Serial.begin(115200, SERIAL_8N1);
  // Wait until data transmission through serial port is completed (in case there's a transmission going on)
  Serial.flush();
  delay(2000);

  // Set SPI communication. 2 MHz clock, MSB first, Mode 0.
  // MODE 0 = Output Edge: Falling - Data Capture: Rising (Data Sheet, p. 38)
  // MODE 1 = Output Edge: Rising - Data Capture: Falling (Data Sheet, p. 38)
  SPI.beginTransaction(SPISettings(2000000, MSBFIRST, SPI_MODE1));
  // Initialize SPI.
  SPI.begin();

  // Set Pin modes
  pinMode(PIN_DRDY, INPUT);
  pinMode(PIN_MISO, INPUT);
  pinMode(PIN_START, OUTPUT);
  pinMode(PIN_SS, OUTPUT);
  pinMode(PIN_MOSI, OUTPUT);
  pinMode(PIN_SCK, OUTPUT);

  // Enable device to configure it
  digitalWrite(PIN_START, LOW);
  digitalWrite(PIN_SS, HIGH);

  /* Follow initial flow at power-up (page 62) */
  // Delay>tPOR in ms (make sure thatVCAP1 1.1v = ok)
  delay(300);
  // Reset the device
  send_command_and_wait(RESET, 18 * tCLK); // (Datasheet, p.35)
  delay(500);
  send_command_and_wait(SDATAC, 4 * tCLK);
  delay(300);

  /* TEST 1 */
  // Read ADS1299 ID to check that it receives data and there's a communication established
  while (device_id == 0) {
    get_device_id();
  }
  // Switch internal reference on (p.48)
  fWREG(CONFIG3, 0xEC);// 0x60 -> enable internal ref, 0xE0 -> power down internal ref
  fWREG(BIAS_SENSP, 0x03); // Bias IN1P + IN2P
  fWREG(BIAS_SENSN, 0x03); // Bias IN1N + IN2N

  // Define the Data rate (p.46)
  // [Set at minimum always, then changed by the desired value]
  fWREG(CONFIG1, 0x96); // 16kSPS -> 0x90, 8kSPS -> 0x91, ..., 250SPS -> 0x96

  // Define test signals (p.47)
  fWREG(CONFIG2, 0xD0); // external test signal -> 0xC0, internal test signal -> 0xD0
  // 0 always ; 0  1*-(VREFP-VREFN)/2400) 1 2*-(VREFP-VREFN)/2400) - 00 fclk/2^21  01 fclk/2^20  11 at dc

  // Activate this for reference mode
  // fWREG(MISC1, 0x20);

  /* TEST 2 */
  // Read the written registers and print data
  if (verbose) {
    Serial.println("Check config regs:");
    Serial.print("CONFIG1: ");
    Serial.println(fRREG(CONFIG1), HEX);
    Serial.print("CONFIG2: ");
    Serial.println(fRREG(CONFIG2), HEX);
    Serial.print("CONFIG3: ");
    Serial.println(fRREG(CONFIG3), HEX);
  }

  // Configure all channels (p.50)
  //0x00 normal operation, unity gain & normal electrode input
  //0x60 normal operation, gain x24 & normal electrode input
  //0x01 normal operation, unity gain & input shorted
  //0x81 power-down, unity gain & input shorted
  //0x05 normal operation, unity gain & test signal
  fWREG(CH1SET, 0x60);
  fWREG(CH2SET, 0x60);
  fWREG(CH3SET, 0x81);
  fWREG(CH4SET, 0x81);
  fWREG(CH5SET, 0x81);
  fWREG(CH6SET, 0x81);
  fWREG(CH7SET, 0x81);
  fWREG(CH8SET, 0x81);

  /* TEST 3 */
  // Read configured channels and registers. Print data.
  if (verbose) {
    Serial.println("Check channels:");
    Serial.print("CH1SET: ");
    Serial.println(fRREG(CH1SET), HEX);
    Serial.print("CH4SET: ");
    Serial.println(fRREG(CH4SET), HEX);// we may have trouble here since it has to print a binary, if not use print(xxx, BIN)
  }

  /* All config is done. 
  Start the device and enable continuous data read mode */
  digitalWrite(PIN_START, LOW);
  delay(150);
  send_command(START);
  delay(150);
  send_command(RDATAC);
}

// Operation loop for the Arduino
void loop() {
  // Wait until there is data available
  while (digitalRead(PIN_DRDY) == HIGH);
  if (verbose) {
    Serial.print("There is Data Ready.\n");
  }
  delay(1);

  // Discard header (first 24 bits)
  digitalWrite(SS, LOW);
  delayMicroseconds(1);
  SPI.transfer(0x00);
  SPI.transfer(0x00);
  SPI.transfer(0x00);

  // Now read the active channels
  for (int i=0; i < active_channels; i++){
    long long_val = 0;
    // Each channel has 24 bits
    byte c1 = SPI.transfer(0x00);
    byte c2 = SPI.transfer(0x00);
    byte c3 = SPI.transfer(0x00);

    // Now rebuild the number received
    unsigned long b1 = 0;
    unsigned long b2 = 0;
    unsigned long b3 = 0;

    // Check whether it's positive or negative and process it differently
    if (c1>0x7F) {
      b1 = ((unsigned long)c1)<<16;
      b2 = ((unsigned long)c2)<<8;
      b3 = (unsigned long)c3;
      long_val = 0xFF000000|b1|b2|b3;  
    } else {
      b1 = (unsigned long)c1<<16;
      b2 = (unsigned long)c2<<8;
      b3 = (unsigned long)c3;
      long_val = b1|b2|b3;
    }

    // Map the input data to the corresponding output value (Datasheet, p. 38)
    float float_val =(float)(long_val * 4500 /( pow(2, 23) - 1));

    // Convert the data to byte
    byte * data = (byte *) &float_val;
    Serial.write(data,4);
  }
  // Release the chip
  digitalWrite(SS, HIGH);
  delayMicroseconds(1);
}

/* SYSTEM COMMANDS */

/* Wake-up from standby mode
 * TODO: Send this as a command too (once figured out how to handle
 * the intermediate delay).
 */
void wake_up() {
  // Set SS low to communicate with device.
  digitalWrite(SS, LOW);
  SPI.transfer(WAKEUP);
  // Must wait at least 4 tCLK cycles (Datasheet, p. 40)
  delay(4 * tCLK);
  // SS high to end communication
  digitalWrite(SS, HIGH);
}

/* Sends a command to the ADS1299. 
 * Requires no delay.
 * @param command: command to issue.
*/
void send_command(uint8_t command) {
  digitalWrite(SS, LOW);
  delay(1);
  SPI.transfer(command);
  delay(1);
  digitalWrite(SS, HIGH);
}

/* Sends a command to the ADS 1299.
 * Issues a delay afterwards. 
 * @param command: command to issue.
 * @param time_to_wait: delay after issuing the command.
*/
void send_command_and_wait(uint8_t command, float time_to_wait) {
  digitalWrite(SS, LOW);
  SPI.transfer(command);
  digitalWrite(SS, HIGH);
  delay(time_to_wait);
}

/* REGISTER READ/WRITE COMMANDS */

/* Read from register.
 * @param address: the starting register address.
 * @return the block of data read.
*/
byte fRREG(byte address) {
  // RREG expects 001rrrrr where rrrrr = _address
  byte op_code = RREG + address;
  digitalWrite(SS, LOW);
  SPI.transfer(op_code);
  SPI.transfer(0x00);
  byte data = SPI.transfer(0x00);
  // Close SPI
  digitalWrite(SS, HIGH);
  delay(1);
  return data;
}

/* Writes to register.
 * @param address: the starting register address.
 * @param data: value to write.
*/
void fWREG(byte address, byte data) {
  // WREG expects 001rrrrr where rrrrr = _address
  // Open SPI.
  byte op_code = WREG + address;
  digitalWrite(SS, LOW);
  SPI.transfer(op_code);
  // Write only one register
  SPI.transfer(0x00);
  SPI.transfer(data);
  // Close SPI
  digitalWrite(SS, HIGH);
  if (verbose) {
    Serial.print("Register 0x");
    Serial.print(address, HEX);
    Serial.println(" modified.\n");
  }
  delay(1);
}

/* Retrieves the device ID and stores it to device_id.
 */
void get_device_id() {
  byte data = fRREG(ID);
  // If retrieved ID is valid, then no power up is needed
  device_id = data;
  if (verbose) {
    Serial.println("Device ID: ");
    Serial.println(device_id, BIN);
  }
}
