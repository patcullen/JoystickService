import at.wisch.joystick.*; // for the joystick
import at.wisch.joystick.exception.FFJoystickException;
import java.util.Iterator; // for the mapping: enumerating through the joystick keys
import processing.net.*; // for the HTTP json server

// some constants
static int fontSize = 15;
static int serverPort = 28080;

// global vars used throughout
ArrayList<Joystick> joysticks;  // joysticks is returned by SDL//FFJoystick library
Joystick joystick; // used to read and interface with joystick (FFJoystick library)
HashMap<String, String> mapping; // used to map values from joystick to result in HTTP
String result; // the most up-to-date result returned from the joystick
Server httpServer; // HTTP Server

// setup the joystick, mapping, and display frame
void setup() {
  // setup connection to joystick
  try {
    JoystickManager.init();
    joysticks = JoystickManager.getAllJoysticks();
    joystick = JoystickManager.getJoystick();
  } catch (FFJoystickException e) {
    e.printErrorMessage();
  }
  if (joysticks.isEmpty()) System.exit(0);
  
  // load mapping from file
  JSONObject mappingJSON = loadJSONObject("mapping.json");
  mapping = new HashMap<String, String>();
  Iterator keys = mappingJSON.keyIterator();
  while (keys.hasNext()) {
    String key = (String)keys.next();
    mapping.put(mappingJSON.getString(key), key);
  }
  result = "";
  
  // setup frame
  frame.setTitle("Joystick");
  size(330, 180);
  textSize(fontSize); 
  fill(0);
  
  // setup web server
  httpServer = new Server(this, serverPort);
}

// check if there are requests for joystick state on the HTTP server
void drawHTTP() {
  try {
    Client c = httpServer.available();
    if (c != null) {
      String input = c.readString();
      input = input.substring(0, input.indexOf("\n")); // Only up to the newline
      
      if (input.indexOf("GET /") == 0) {
        // write that we're ok and send header
        c.write("HTTP/1.0 200 OK\r\nContent-Type: text/json\r\n\r\n");
        // write the last state of the joystick
        c.write(result);
        // close connection to client, otherwise it's gonna wait forever
        c.stop();
      }
    }
  } catch(Exception err) {
    // ignore any exceptions generated from here. 
    // some web clients could not conform and break the app.
  }
}


// continually loop and read from joystick. update display frame and output for http.
void draw() {
  // setup canvas
  background(255);
  int y = 0;
  String nResult = "{\"name\": \"" + joystick.getName() + "\"";
  
  joystick.poll();
  text("Name: " + joystick.getName(), 10, 20);
  
  for (int i = 0; i < joystick.getAxisCount(); i++) {
    // display axis values
    text(joystick.getAxisName(i) + ": " + joystick.getAxisValue(i), 10, 20 + ++y * fontSize);
    // JSON
    if (mapping.containsKey(joystick.getAxisName(i)))
      nResult += ", \"" + mapping.get(joystick.getAxisName(i)) + "\": " + joystick.getAxisValue(i);
  }
  for (int i = 0; i < joystick.getPovCount(); i++) {
    // display POV values
    text("POV" + joystick.getPovName(i) + ": " + joystick.getPovDirection(i), 10, 20 + ++y * fontSize);
    // JSON
    if (mapping.containsKey("POV"+joystick.getPovName(i)))
      nResult += ", \"" + mapping.get("POV"+joystick.getPovName(i)) + "\": " + joystick.getPovDirection(i);
  }
  String buttons = "Buttons: ";
  for (int i = 0; i < joystick.getButtonCount(); i++) {
    // display buttons
    if (joystick.isButtonPressed(i))
      buttons += " B" + joystick.getButtonName(i);
    // JSON
    if (mapping.containsKey("B"+joystick.getButtonName(i)))
      nResult += ", \"" + mapping.get("B"+joystick.getButtonName(i)) + "\": " + (joystick.isButtonPressed(i) ? "true" : "false");
  }
  text(buttons, 10, 20 + ++y * fontSize);
  
  nResult += "}";
  result = nResult; // done like this to prevent any chance of a http request getting a half built json packet
  
  drawHTTP(); // check server for any requests from clients
}

void stop() {
  JoystickManager.close();
} 
