/*
* Code for a custom audio player to interface with Arduino input over the serial port.
*/

/*
* This program was developed with use of the Minim audio library for Processing.
 * Four of the example sketches from the main library have been adapted to form graphical
 * components of the programme, specifically:
 * - SoundEnergyBeatDetection
 * - AnalyzeSound
 * - DrawWaveformAndLevel
 * - skip
 */

//Import the libraries used in the programme:
import processing.serial.*;    //Serial port
import ddf.minim.*;            //Minim audio playback engine
import ddf.minim.analysis.*;   //Minim audio analysis engine

// Call the custom audio objects for the programme:
Minim audioEngine;             // New instance of Minim audio engine 
AudioPlayer musicPlayer;       // New mp3 file audio player 
AudioMetaData meta;            // New metadata handler 
FFT spectrum;                  // New FFT spectrum analysis module
BeatDetect beat;               // New beat detection module

// Call the serial port object:
Serial myPort;  

// Call the font class
PFont programmeFont; 

// Global variables:
float eRadius, posx;    // BeatDetect spot size and playback line position
int val;                // Container for serial port data
int currentTrack =0, currentPosition=0;  // Containers audio playback parameters
int totalWholeMinutes, totalWholeTens, totalSeconds; // Total file time containers
Table playlist;         // Playlist data table
String fileName;        // Container for filename
int trackYear;          // Container for track year 


void setup() 
{
  size(1280, 800);

  // Setup audio engine, load a placeholder file, set the buffer size and pause the audio
  audioEngine = new Minim(this);
  musicPlayer = audioEngine.loadFile("Silence.mp3", 1024);
  musicPlayer.pause();

  //Get the file's metadata
  meta = musicPlayer.getMetaData();

  // Setup spectral analysis
  spectrum = new FFT( musicPlayer.bufferSize(), musicPlayer.sampleRate() );

  // Setup enegry detection
  beat = new BeatDetect();

  // Open Serial Port 1
  String portName = Serial.list()[1];
  myPort = new Serial(this, portName, 115200);

  // Load the .csv data file table
  playlist = loadTable("trackData.csv", "header");

  // Load and assomg the font
  programmeFont = loadFont("Avenir-Black-100.vlw");
  textFont(programmeFont);

  //Set the mode for ellipse drawing
  ellipseMode(RADIUS);
}


void draw()
{
  // Send a ASCII message to turn on the red LED
  myPort.write('R');

  background(50);

  if ( myPort.available() > 0) {  // If data is available,
    val = myPort.read(); // Read the value from the serial port

    // If it is the dial's home state value
    // pause the audio, reset the playback postion and refresh the track data
    if (val ==48) {
      musicPlayer.pause();
      myPort.write('g');
      refreshTrack();
    }
    // If it is a used dial value, change the track
    else if (val >= 49 && val <=73) {  
      changeTrack();
    }
    // If it is an unused dial value, pause the audio and refresh the track data
    else if (val >= 74 && val <=87) {
      musicPlayer.pause();
      myPort.write('g');
      refreshTrack();
    }
    // If it is a slider value, navigate to the new position
    else if (val >=97 && val <=102) {
      navigateTrack();
    }
  }


  /* Waveform drawing code taken from Minim "DrawWaveformAndLevel" example sketch
   * Stroke color to fit program theme 
   */
  stroke(18, 255, 15);
  // draw the waveforms
  // the values returned by left.get() and right.get() will be between -1 and 1,
  // so we need to scale them up to see the waveform
  // note that if the file is MONO, left.get() and right.get() will return the same value
  for (int i = 0; i < musicPlayer.bufferSize() - 1; i++)
  {
    float x1 = map( i, 0, musicPlayer.bufferSize(), 0, width );
    float x2 = map( i+1, 0, musicPlayer.bufferSize(), 0, width );
    line( x1, 50 + musicPlayer.left.get(i)*50, x2, 50 + musicPlayer.left.get(i+1)*50 );
    line( x1, 150 + musicPlayer.right.get(i)*50, x2, 150 + musicPlayer.right.get(i+1)*50 );
  }


  /* Playback line drawing code adapted from Minim "skip" example sketch
   * Modifications highlighed in line 
   */
  posx = map(musicPlayer.position(), 0, musicPlayer.length(), 0, width);
  stroke(77, 77, 255);      // Stroke colour changed to suit program theme
  strokeWeight(3);          // Stroke weight increased
  line(posx, 5, posx, 220);  // Line inset from screen edge and height increased


  /* Spectrum analysis code adapted from Minim "AnalyzeSound" example sketch
   * Modifications highlighed in line 
   */
  // perform a forward FFT on the samples in musicPlayer's mix buffer,
  // which contains the mix of both the left and right channels of the file
  spectrum.forward(musicPlayer.mix);
  stroke(18, 255, 15); // Stroke colour changed to match main program theme
  strokeWeight(1);
  for (int i = 0; i < spectrum.specSize(); i++)
    // Scaling and position of spectrum changed to fill screen
  {
    // draw the line for frequency band i, scaling it up a bit so we can see it
    line( i+20, height-20, i+20, height -20 - spectrum.getBand(i)*10 );
  }


  /* Spectrum analysis code adapted from Minim "SoundEnergyDetection" example sketch
   * Modifications highlighed in line 
   */
  noStroke();
  beat.detect(musicPlayer.mix);
  float a = map(eRadius, 20, 80, 60, 255);
  fill(18, 255, 15, a); // Fill colour changed to match main program theme
  if ( beat.isOnset() ) {
    eRadius = 150;      // Radius of ellipse enlarged to encompass year text
  }
  ellipse(width/2, height/2, eRadius, eRadius);
  // Overlay an arc with a different fill, analogous to the metronome dial position 
  fill(255, 160, 53, a);
  arc(width/2, height/2, eRadius, eRadius, HALF_PI, HALF_PI+(2*PI/40*(currentTrack)), PIE);
  // Reduce the radius on each iteration (until re-triggered)
  // Allow the radius to dimish indefinitely
  eRadius *= 0.95; 


  //Additional drawing routine whilst music is playing:
  if ( musicPlayer.isPlaying() )
  {
    drawYear();    // Piece year and corresponding segment outline
    drawTimes();   // Update playback times
    textSize(40);  
    fill(255);
    text(meta.title(), width/2, height/4*3); // Return file ID3 title
    textAlign(RIGHT, BOTTOM);
    textSize(20);
    text(meta.author(), width-20, height-20); // Return file ID3 artist
  } else
  {
    // Additional drawing rountine for home screen:
    if (currentTrack==0) {
      currentPosition=0;
      noFill();
      stroke(255);
      ellipse(width/2, height/2, 150, 150);
      textAlign(CENTER, CENTER);
      textSize(50);
      fill(214, 27, 17);
      text("Metronome Music Time Capsule", width/2, height/2);
      textSize(30);
      fill(255);
      text(meta.title(), width/2, height/4*3);
      textAlign(RIGHT, BOTTOM);
      textSize(20);
      text("Use the slider to skip back and forth", width-20, height-20);
    } else {
      // Additional drawing rountine in empty position cases:
      drawYear();
      textSize(30);
      fill(255);
      text(meta.title(), width/2, height/4*3);
      textAlign(RIGHT, BOTTOM);
      textSize(20);
      text(meta.author(), width-20, height-20);
    }
  }
}


// Routing for drawing playback times
void drawTimes() {
  textSize(20);
  fill(255);
  // Calculate minutes from milliseconds as a float and store whole minute integer
  float elapsedMinutes = musicPlayer.position()/60000;
  int elapsedWholeMinutes = floor(elapsedMinutes); 
  // Calculate tens of seconds from remainder and store whole tens integer
  int elapsedTens = (musicPlayer.position()-(elapsedWholeMinutes*60000))/10000;
  int elapsedWholeTens = floor(elapsedTens);
  // Calculate remaining seconds and round to nearest integer
  int elapsedSeconds = round((musicPlayer.position()-(elapsedWholeMinutes*60000)
    -(elapsedWholeTens*10000))/1000);
  // Draw component digits with separator  
  textAlign(RIGHT, BOTTOM);
  text(elapsedWholeMinutes + ":" + elapsedWholeTens + elapsedSeconds, width-20, 200);
  // Draw total time values with separators
  textAlign(CENTER, BOTTOM);
  text(totalWholeMinutes + "m" + totalWholeTens + totalSeconds+"s", width/2, height/5*4);
}


// Routing for drawing year text and arc segment outline
void drawYear() {
  noFill();
  stroke(255);
  arc(width/2, height/2, 150, 150, HALF_PI, HALF_PI+(2*PI/40*(currentTrack)), PIE);

  textAlign(CENTER, CENTER);
  textSize(100);
  fill(214, 27, 17);
  text(playlist.getString(currentTrack, "year"), width/2, height/2);
}


//Changetrack function
void changeTrack() {
  refreshTrack();
  resumePlayback();
}

//RefreshTrack function - stop audio, reassign control values, redraw track data
void refreshTrack() {
  musicPlayer.pause();
  currentTrack = val-48;
  currentPosition=0;
  drawYear();
  String fileName = playlist.getString(currentTrack, "filename");
  musicPlayer = audioEngine.loadFile(fileName, 1024);
  meta = musicPlayer.getMetaData();
}


//ResumePlayback function - calculate total playback time (as above), activate green LED
void resumePlayback() {
  int totalMinutes = musicPlayer.length()/60000;
  totalWholeMinutes = floor(totalMinutes);
  int totalTens = (musicPlayer.length()-totalWholeMinutes*60000)/10000;
  totalWholeTens = floor(totalTens);
  totalSeconds = round((musicPlayer.length()-(totalWholeMinutes*60000)
          -(totalWholeTens*10000))/1000);
  musicPlayer.play(currentPosition);
  myPort.write('G');
}


//NavigateTrack function
//Stop audio, relocate playback position according to slider position then resume audio
void navigateTrack() {
  musicPlayer.pause();
  if (currentTrack!=0) {
    int trackLength = musicPlayer.length();
    if (val==97) {
      currentPosition= 0;
    } else if (val ==98) {    
      currentPosition=trackLength/6;
    } else if (val ==99) {        
      currentPosition=trackLength/6*2;
    } else if (val ==100) {
      currentPosition=trackLength/6*3;
    } else if (val ==101) {
      currentPosition=trackLength/6*4;
    } else if (val ==102) {
      currentPosition=trackLength/6*5;
    }
    resumePlayback();
  }
}


// Enable "Esc" as a hotkey to stop audio, turn of LEDs and exit program
void keyPressed() {
  if (keyCode == ESC) { 
    stop();
    myPort.write('r');
    myPort.write('g');
    exit();
  }
}