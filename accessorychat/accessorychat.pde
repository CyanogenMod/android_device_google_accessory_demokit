#include <Max3421e.h>
#include <usb.h>

#define USB_ACCESSORY_VENDOR_ID 0x18D1
#define USB_ACCESSORY_PRODUCT_ID 0x2D00

#define USB_ACCESSORY_ADB_PRODUCT_ID 0x2D01
#define ACCESSORY_STRING_MANUFACTURER 0
#define ACCESSORY_STRING_MODEL 1
#define ACCESSORY_STRING_TYPE 2
#define ACCESSORY_STRING_VERSION 3

#define ACCESSORY_SEND_STRING 52
#define ACCESSORY_START 53

MAX3421E Max;
USB Usb;

void setup();
void loop();

uint8_t usbBuff[256];

void setup()
{
	Serial.begin( 115200 );
	Serial.print("\r\nStart");
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

void sendString(byte addr, int index, char *str)
{
	Usb.ctrlReq(addr, 0, USB_SETUP_HOST_TO_DEVICE | USB_SETUP_TYPE_VENDOR | USB_SETUP_RECIPIENT_DEVICE,
		    ACCESSORY_SEND_STRING, 0, 0, index, strlen(str) + 1, str);

}

void switchDevice(byte addr)
{
	sendString(addr, ACCESSORY_STRING_MANUFACTURER, "Google, Inc.");
	sendString(addr, ACCESSORY_STRING_MODEL, "AccessoryChat");
	sendString(addr, ACCESSORY_STRING_TYPE, "Sample Program");
	sendString(addr, ACCESSORY_STRING_VERSION, "1.0");

	Usb.ctrlReq(addr, 0, USB_SETUP_HOST_TO_DEVICE | USB_SETUP_TYPE_VENDOR | USB_SETUP_RECIPIENT_DEVICE,
		    ACCESSORY_START, 0, 0, 0, 0, NULL);
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
				ep->epAddr = epDesc->bEndpointAddress;
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

EP_RECORD ep_record[ 3 ];  //endpoint record structure for the mouse


void doAndroid(void)
{
	byte err;
	byte idle;

	if (findEndpoints(1, &ep_record[1], &ep_record[2])) {
		Serial.print("inEp: ");
		Serial.println(ep_record[1].epAddr, HEX);
		Serial.print("outEp: ");
		Serial.println(ep_record[2].epAddr, HEX);

		ep_record[0] = *(Usb.getDevTableEntry(0,0));
		Usb.setDevTableEntry(1, ep_record);

		err = Usb.setConf( 1, 0, 1 );
		if (err)
			Serial.print("Can't set config to 1\n");

		Usb.setUsbTaskState( USB_STATE_RUNNING );

		while(1) {
			int len = Usb.newInTransfer(1, 1, sizeof(usbBuff),
						    (char *)usbBuff);
			int i;

			if (len > 0) {
				for (i = 0; i < len; i++)
					Serial.print((char)usbBuff[i]);
				Serial.print('\n');
			}

			Usb.outTransfer(1, 2, strlen("ping"), "ping");
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

