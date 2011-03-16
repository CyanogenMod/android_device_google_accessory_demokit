#include <Max3421e.h>
#include <Usb.h>
#include <Wire.h>
#include <Servo.h>

#define USB_ACCESSORY_VENDOR_ID 0x18D1
#define USB_ACCESSORY_PRODUCT_ID 0x2D00

#define USB_ACCESSORY_ADB_PRODUCT_ID 0x2D01
#define ACCESSORY_STRING_MANUFACTURER 0
#define ACCESSORY_STRING_MODEL 1
#define ACCESSORY_STRING_DESCRIPTION 2
#define ACCESSORY_STRING_VERSION 3
#define ACCESSORY_STRING_URI 4
#define ACCESSORY_STRING_SERIAL 5

#define ACCESSORY_GET_PROTOCOL 51
#define ACCESSORY_SEND_STRING 52
#define ACCESSORY_START 53


#define  LED3_RED       2
#define  LED3_GREEN     3
#define  LED3_BLUE      4

#define  LED2_RED       5
#define  LED2_GREEN     6
#define  LED2_BLUE      7

#define  LED1_RED       8
#define  LED1_GREEN     9
#define  LED1_BLUE      10

#define  SERVO1         11
#define  SERVO2         12
#define  SERVO3         13

#define  TOUCH          14

#define  RELAY1         A0
#define  RELAY2         A1

#define  LIGHT_SENSOR   A2
#define  TEMP_SENSOR    A3

#define  BUTTON1        A6
#define  BUTTON2        A7
#define  BUTTON3        A8

#define  JOY_SWITCH     A9      // pulls line down when pressed
#define  JOY_nINT       A10     // active low interrupt input
#define  JOY_nRESET     A11     // active low reset output


MAX3421E Max;
USB Usb;
Servo servos[3];


void setup();
void loop();

uint8_t usbBuff[256];


void init_buttons()
{
	pinMode( BUTTON1, INPUT );
	pinMode( BUTTON2, INPUT );
	pinMode( BUTTON3, INPUT );

	digitalWrite( BUTTON1, HIGH );  // enable the internal pullups
	digitalWrite( BUTTON2, HIGH );
	digitalWrite( BUTTON3, HIGH );
}


void init_relays()
{
	pinMode( RELAY1, OUTPUT );
	pinMode( RELAY2, OUTPUT );
}


void init_leds()
{
	digitalWrite( LED1_RED,   1 );
	digitalWrite( LED1_GREEN, 1 );
	digitalWrite( LED1_BLUE,  1 );

	pinMode( LED1_RED,    OUTPUT );
	pinMode( LED1_GREEN,  OUTPUT );
	pinMode( LED1_BLUE,   OUTPUT );

	digitalWrite( LED2_RED,   1 );
	digitalWrite( LED2_GREEN, 1 );
	digitalWrite( LED2_BLUE,  1 );

	pinMode( LED2_RED,    OUTPUT );
	pinMode( LED2_GREEN,  OUTPUT );
	pinMode( LED2_BLUE,   OUTPUT );

	digitalWrite( LED3_RED,   1 );
	digitalWrite( LED3_GREEN, 1 );
	digitalWrite( LED3_BLUE,  1 );

	pinMode( LED3_RED,    OUTPUT );
	pinMode( LED3_GREEN,  OUTPUT );
	pinMode( LED3_BLUE,   OUTPUT );
}

void init_joystick( int threshold );

void setup()
{
	Serial.begin( 115200 );
	Serial.print("\r\nStart");

	init_leds();
	init_relays();
	init_buttons();
	init_joystick( 5 );      // initialize with thresholding enabled, dead zone of 5 units  


	servos[0].attach(SERVO1);
	servos[0].write(90);
	servos[1].attach(SERVO2);
	servos[1].write(90);
	servos[2].attach(SERVO3);
	servos[2].write(90);

	Max.powerOn();
	delay( 200 );
}

bool isAndroidVendor(USB_DEVICE_DESCRIPTOR *desc)
{
	return desc->idVendor == 0x18d1 || desc->idVendor == 0x22B8;
}

bool isAccessoryDevice(USB_DEVICE_DESCRIPTOR *desc)
{
	return desc->idProduct == 0x2D00 || desc->idProduct == 0x2D01;
}

int getProtocol(byte addr)
{
        uint16_t protocol = -1;
        Usb.ctrlReq(addr, 0, USB_SETUP_DEVICE_TO_HOST | USB_SETUP_TYPE_VENDOR | USB_SETUP_RECIPIENT_DEVICE,
		    ACCESSORY_GET_PROTOCOL, 0, 0, 0, 2, (char *)&protocol);
        return protocol;
}

void sendString(byte addr, int index, char *str)
{
	Usb.ctrlReq(addr, 0, USB_SETUP_HOST_TO_DEVICE | USB_SETUP_TYPE_VENDOR | USB_SETUP_RECIPIENT_DEVICE,
		    ACCESSORY_SEND_STRING, 0, 0, index, strlen(str) + 1, str);

}

bool switchDevice(byte addr)
{
        int protocol = getProtocol(addr);
        if (protocol == 1)
                Serial.print("device supports protcol 1\n");
        else {
                Serial.print("could not read device protocol version\n");
                return false;
        }
	sendString(addr, ACCESSORY_STRING_MANUFACTURER, "Google, Inc.");
	sendString(addr, ACCESSORY_STRING_MODEL, "DemoKit");
	sendString(addr, ACCESSORY_STRING_DESCRIPTION, "DemoKit test board");
	sendString(addr, ACCESSORY_STRING_VERSION, "1.0");
	sendString(addr, ACCESSORY_STRING_URI, "http://www.android.com");
	sendString(addr, ACCESSORY_STRING_SERIAL, "0000000012345678");

	Usb.ctrlReq(addr, 0, USB_SETUP_HOST_TO_DEVICE | USB_SETUP_TYPE_VENDOR | USB_SETUP_RECIPIENT_DEVICE,
		    ACCESSORY_START, 0, 0, 0, 0, NULL);
        return true;
}

bool findEndpoints(byte addr, EP_RECORD *inEp, EP_RECORD *outEp)
{
	int len;
	byte err;
	uint8_t *p;

	err = Usb.getConfDescr(addr, 0, 4, 0, (char *)usbBuff);
	if (err) {
		Serial.print("Can't get config descriptor length\n");
		return false;
	}

	len = usbBuff[2] | ((int)usbBuff[3] << 8);
	Serial.print("Config Desc Length: ");
	Serial.println(len, DEC);
	if (len > sizeof(usbBuff)) {
		Serial.print("config descriptor too large\n");
		/* might want to truncate here */
		return false;
	}

	err = Usb.getConfDescr(addr, 0, len, 0, (char *)usbBuff);
	if (err) {
		Serial.print("Can't get config descriptor\n");
		return false;
	}

	p = usbBuff;
	inEp->epAddr = 0;
	outEp->epAddr = 0;
	while (p < (usbBuff + len)){
		uint8_t descLen = p[0];
		uint8_t descType = p[1];
		USB_ENDPOINT_DESCRIPTOR *epDesc;
		EP_RECORD *ep;

		switch (descType) {
		case USB_DESCRIPTOR_CONFIGURATION:
			Serial.print("config desc\n");
			break;

		case USB_DESCRIPTOR_INTERFACE:
			Serial.print("interface desc\n");
			break;

		case USB_DESCRIPTOR_ENDPOINT:
			epDesc = (USB_ENDPOINT_DESCRIPTOR *)p;
			if (!inEp->epAddr && (epDesc->bEndpointAddress & 0x80))
				ep = inEp;
			else if (!outEp->epAddr)
				ep = outEp;
			else
				ep = NULL;

			if (ep) {
				ep->epAddr = epDesc->bEndpointAddress & 0x7f;
				ep->Attr = epDesc->bmAttributes;
				ep->MaxPktSize = epDesc->wMaxPacketSize;
				ep->sndToggle = bmSNDTOG0;
				ep->rcvToggle = bmRCVTOG0;
			}
			break;

		default:
			Serial.print("unkown desc type ");
			Serial.println( descType, HEX);
			break;
		}

		p += descLen;
	}

	return inEp->epAddr && outEp->epAddr;
}

EP_RECORD ep_record[ 8 ];  //endpoint record structure for the mouse


void doAndroid(void)
{
	byte err;
	byte idle;
	byte b1, b2, b3, c;
	EP_RECORD inEp, outEp;
	byte count = 0;

	if (findEndpoints(1, &inEp, &outEp)) {

		ep_record[inEp.epAddr] = inEp;
		if (outEp.epAddr != inEp.epAddr)
			ep_record[outEp.epAddr] = outEp;

		Serial.print("inEp: ");
		Serial.println(inEp.epAddr, HEX);
		Serial.print("outEp: ");
		Serial.println(outEp.epAddr, HEX);

		ep_record[0] = *(Usb.getDevTableEntry(0,0));
		Usb.setDevTableEntry(1, ep_record);

		err = Usb.setConf( 1, 0, 1 );
		if (err)
			Serial.print("Can't set config to 1\n");

		Usb.setUsbTaskState( USB_STATE_RUNNING );

		b1 = digitalRead(BUTTON1);
		b2 = digitalRead(BUTTON2);
		b3 = digitalRead(BUTTON3);
		c = captouched();

		while(1) {
			int len = Usb.newInTransfer(1, inEp.epAddr, sizeof(usbBuff),
						    (char *)usbBuff, 1);
			int i;
			byte b;
			byte msg[3];
			msg[0] = 0x1;

			if (len > 0) {
				// XXX: assumes only one command per packet
				Serial.print(usbBuff[0], HEX);
				Serial.print(":");
				Serial.print(usbBuff[1], HEX);
				Serial.print(":");
				Serial.println(usbBuff[2], HEX);
				if (usbBuff[0] == 0x2) {
					if (usbBuff[1] == 0x0)
						analogWrite( LED1_RED, 255 - usbBuff[2]);
					else if (usbBuff[1] == 0x1)
						analogWrite( LED1_GREEN, 255 - usbBuff[2]);
					else if (usbBuff[1] == 0x2)
						analogWrite( LED1_BLUE, 255 - usbBuff[2]);
					else if (usbBuff[1] == 0x3)
						analogWrite( LED2_RED, 255 - usbBuff[2]);
					else if (usbBuff[1] == 0x4)
						analogWrite( LED2_GREEN, 255 - usbBuff[2]);
					else if (usbBuff[1] == 0x5)
						analogWrite( LED2_BLUE, 255 - usbBuff[2]);
					else if (usbBuff[1] == 0x6)
						analogWrite( LED3_RED, 255 - usbBuff[2]);
					else if (usbBuff[1] == 0x7)
						analogWrite( LED3_GREEN, 255 - usbBuff[2]);
					else if (usbBuff[1] == 0x8)
						analogWrite( LED3_BLUE, 255 - usbBuff[2]);
					else if (usbBuff[1] == 0x10)
						servos[0].write(map(usbBuff[2], 0, 255, 0, 180));
					else if (usbBuff[1] == 0x11)
						servos[1].write(map(usbBuff[2], 0, 255, 0, 180));
					else if (usbBuff[1] == 0x12)
						servos[2].write(map(usbBuff[2], 0, 255, 0, 180));
				} else if (usbBuff[0] == 0x3) {
					if (usbBuff[1] == 0x0)
						digitalWrite( RELAY1, usbBuff[2] ? HIGH : LOW );
					else if (usbBuff[1] == 0x1)
						digitalWrite( RELAY2, usbBuff[2] ? HIGH : LOW );

				}

//				for (i = 0; i < len; i++)
//				Serial.print('\n');
			}

			b = digitalRead(BUTTON1);
			if (b != b1) {
				msg[1] = 0;
				msg[2] = b ? 0 : 1;
				Usb.outTransfer(1, outEp.epAddr, 3, (char *)msg);
				b1 = b;
			}

			b = digitalRead(BUTTON2);
			if (b != b2) {
				msg[1] = 1;
				msg[2] = b ? 0 : 1;
				Usb.outTransfer(1, outEp.epAddr, 3, (char *)msg);
				b2 = b;
			}

			b = digitalRead(BUTTON3);
			if (b != b3) {
				msg[1] = 2;
				msg[2] = b ? 0 : 1;
				Usb.outTransfer(1, outEp.epAddr, 3, (char *)msg);
				b3 = b;
			}

			if ((count++ % 16) == 0) {
				uint16_t val;
				int x, y;

				val = analogRead(TEMP_SENSOR);
				msg[0] = 0x4;
				msg[1] = val >> 8;
				msg[2] = val & 0xff;
				Usb.outTransfer(1, outEp.epAddr, 3, (char *)msg);

				val = analogRead(LIGHT_SENSOR);
				msg[0] = 0x5;
				msg[1] = val >> 8;
				msg[2] = val & 0xff;
				Usb.outTransfer(1, outEp.epAddr, 3, (char *)msg);

				read_joystick(&x, &y);
				msg[0] = 0x6;
				msg[1] = constrain(x, -128, 127);
				msg[2] = constrain(y, -128, 127);
				Usb.outTransfer(1, outEp.epAddr, 3, (char *)msg);

				char c0 = captouched();
				if (c0 != c) {
					msg[0] = 0x1;
					msg[1] = 3;
					msg[2] = c0 ? 0 : 1;
					Usb.outTransfer(1, outEp.epAddr, 3, (char *)msg);
					c = c0;
				}
			}

			delay(10);

		}

	}

}


void loop()
{
	USB_DEVICE_DESCRIPTOR *devDesc = (USB_DEVICE_DESCRIPTOR *) usbBuff;
	byte err;

	Max.Task();
	Usb.Task();
	if( Usb.getUsbTaskState() >= USB_STATE_CONFIGURING ) {
		Serial.print("\nDevice addressed... ");
		Serial.print("Requesting device descriptor.");

		err = Usb.getDevDescr(1, 0, 0x12, (char *) devDesc);
		if (err) {
			Serial.print("\nDevice descriptor cannot be retrieved. Program Halted\n");
			while(1);
		}

		if (isAndroidVendor(devDesc)) {
			Serial.print("found android device\n");

			if (isAccessoryDevice(devDesc)) {
				Serial.print("found android acessory device\n");
				doAndroid();
			} else {
				Serial.print("found possible device. swithcing to serial mode\n");
				switchDevice(1);
			}
		}

		while (Usb.getUsbTaskState() != USB_DETACHED_SUBSTATE_WAIT_FOR_DEVICE) {
			Max.Task();
			Usb.Task();


		}

		Serial.print("detached\n");

	}

}

// ==============================================================================
// Austria Microsystems i2c Joystick

/*
  If a threshold is provided, the dead zone will be programmed such that interrupts will not
  be generated unless the threshold is exceeded.

  Note that if you use that mode, you will have to use passage of time with no new interrupts
  to detect that the stick has been released and has returned to center.
  
  If you need to explicitly track return to center, pass 0 as the threshold.  "Center" will
  still bounce around a little 
*/


void init_joystick( int threshold )
{
  byte status = 0;
  
  pinMode( JOY_SWITCH, INPUT );
  digitalWrite( JOY_SWITCH, HIGH );    // enable the internal pullup
  
  pinMode( JOY_nINT, INPUT );
  digitalWrite( JOY_nINT, HIGH );      // enable the internal pullup

  pinMode( JOY_nRESET, OUTPUT );

  digitalWrite( JOY_nRESET, 1 );
  delay(1);
  digitalWrite( JOY_nRESET, 0 );
  delay(1);
  digitalWrite( JOY_nRESET, 1 );

  Wire.begin();
  
  do {
    status = read_joy_reg( 0x0f );        // XXX need timeout
  } while ((status & 0xf0) != 0xf0);
  
  write_joy_reg( 0x2e, 0x86 );            // invert magnet polarity setting, per datasheet

  calibrate_joystick( threshold );        // calibrate & set up dead zone area  
}


int offset_X, offset_Y;

void calibrate_joystick( int dz )
{
  char iii;
  int x_cal = 0;
  int y_cal = 0;

  write_joy_reg( 0x0f, 0x00 );          // Low Power Mode, 20ms auto wakeup
                                        // INTn output enabled
                                        // INTn active after each measurement
                                        // Normal (non-Reset) mode
  delay(1);

  read_joy_reg( 0x11 );                 // dummy read of Y_reg to reset interrupt

  for( iii = 0; iii != 16; iii++ ) {    // read coords 16 times & average 
    while( !joystick_interrupt() )      // poll for interrupt
      ;
    x_cal += read_joy_reg( 0x10 );      // X pos
    y_cal += read_joy_reg( 0x11 );      // Y pos
  }
  
  offset_X = -(x_cal>>4);               // divide by 16 to get average
  offset_Y = -(y_cal>>4);
  
  //sprintf(msgbuf, "offsets = %d, %d\n", offset_X, offset_Y);
  //Serial.print(msgbuf);
  
  write_joy_reg( 0x12,  dz - offset_X );  // Xp, LEFT threshold for INTn
  write_joy_reg( 0x13, -dz - offset_X );  // Xn, RIGHT threshold for INTn
  write_joy_reg( 0x14,  dz - offset_Y );  // Yp, UP threshold for INTn
  write_joy_reg( 0x15, -dz - offset_Y );  // Yn, DOWN threshold for INTn

  if ( dz )                             // dead zone threshold detect requested?
    write_joy_reg( 0x0f, 0x04 );          // Low Power Mode, 20ms auto wakeup
                                          // INTn output enabled
                                          // INTn active when movement exceeds dead zone
                                          // Normal (non-Reset) mode
}


void read_joystick( int *x, int *y )
{
  *x = read_joy_reg( 0x10 ) + offset_X;
  *y = read_joy_reg( 0x11 ) + offset_Y;  // reading Y clears the interrupt
}

char joystick_interrupt()
{
  return ( digitalRead( JOY_nINT ) == 0 ); 
}


#define  JOY_I2C_ADDR    0x40

char read_joy_reg( char reg_addr )
{
  char c;
  
  Wire.beginTransmission( JOY_I2C_ADDR );
  Wire.send( reg_addr );
  Wire.endTransmission();
  
  Wire.requestFrom( JOY_I2C_ADDR, 1 );
  
  while(Wire.available())
    c = Wire.receive();
  
  return c;
}

void write_joy_reg( char reg_addr, char val )
{
  Wire.beginTransmission( JOY_I2C_ADDR );
  Wire.send( reg_addr );
  Wire.send( val );
  Wire.endTransmission();  
}

/* Capacitive touch technique from Mario Becker, Fraunhofer IGD, 2007 http://www.igd.fhg.de/igd-a4 */

char captouched() 
{
  char iii, jjj, retval;
  
  retval = 0;
  
  for( jjj = 0; jjj != 10; jjj++ ) {
    delay( 10 );
  
    pinMode( TOUCH, INPUT );
    digitalWrite( TOUCH, HIGH );
  
    for ( iii = 0; iii <  16; iii++ )
      if( digitalRead( TOUCH ) )
        break;
      
    digitalWrite( TOUCH, LOW );
    pinMode( TOUCH, OUTPUT );
  
    retval += iii;
  }
  
  return retval;
}
