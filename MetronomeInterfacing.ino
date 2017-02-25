/*Code for interfacing "Metronome Music Time Capsule" dial, slider and LEDs
   with a custom audio player Processing programme using the serial port.
*/

/* Global variables*/
char incomingByte;   // Container for incoming serial port message
int dialPosition;    // Container for metronome dial's current position
char dialMessage;    // Container for serial port messages from dial
int sliderPostion;   // Container for metronome slider's current position
int sliderValue;     // Container for slider value


/*Setup the Arduino I/O*/
void setup() {
  // initialise pins 2-10 as inputs:
  for (int i = 2; i <= 10; i++) {
    pinMode(i, INPUT);
  }
  // initialise pins 11&12 as outputs:
  for (int j = 11; j <= 12; j++) {
    pinMode(j, OUTPUT);
  }
  // initialise the serial port at 115200 baud
  Serial.begin(115200);
  digitalWrite(11, LOW);
  digitalWrite(12, LOW);
}


/*Main loop handles serial communication*/
void loop() {

  char sliderMessage[] = {'a', 'b', 'c', 'd', 'e', 'f'}; //Slider message array

  // When the serial port gives a value, read it and interpret which LED should be changed
  while (Serial.available() > 0) {
    incomingByte = Serial.read();
    if (incomingByte == 'R') {
      digitalWrite(11, HIGH);
    }
    if (incomingByte == 'r') {
      digitalWrite(11, LOW);
    }
    if (incomingByte == 'G') {
      digitalWrite(12, HIGH);
    }
    if (incomingByte == 'g') {
      digitalWrite(12, LOW);
    }
  }

  //Check the value of the metronome dial
  checkDial();
  // If it does not match the current position ...
  if (dialMessage != dialPosition) {
    // Check it again to make sure it has stopped moving
    checkDial();
    // Assign the message from the dial as the current dial position
    dialPosition = dialMessage;
    // Write the dial message to the serial port
    Serial.write(dialMessage);
  }

  //Check the value of the metronome slider
  checkSlider();
  // If it does not match the current position ...
  if (sliderValue != sliderPostion) {
    // Check it again to make sure it has stopped moving
    checkSlider();
    // Assign the value from the slider as the current slider positionlue
    sliderPostion = sliderValue;
    // Write the corresponding message from the array to the serial port
    Serial.write(sliderMessage[sliderValue]);
  }
}


/* CheckDial function:
  - Read all input pins using short delay to overcome switch bounce
  - Determine the dial location by summing binary position values
  - Offset the result to avoid use of conflicting ASCII character values
*/
void checkDial() {
  int dialState[6];
  // read the state of the digital inputs:
  for (int i = 5; i <= 10; i++) {
    delay(20);
    dialState[i - 5] = digitalRead(i);
  }
  dialMessage = (dialState[0] * 1)
                + (dialState[1] * 2)
                + (dialState[2] * 4)
                + (dialState[3] * 8)
                + (dialState[4] * 16)
                + (dialState[5] * 32)
                + 48;
}


/* CheckSlider function:
  - Read all input pins using short delay to overcome switch bounce
  - Determine the slider location by summing binary position values
*/
void checkSlider() {
  int sliderState[3];
  for (int j = 2; j <= 4; j++) {
    delay(50);
    sliderState[j - 2] = digitalRead(j);
  }
  sliderValue = (sliderState[0] * 1)
                + (sliderState[1] * 2)
                + (sliderState[2] * 4);
}
