package com.google.DemoKit;

import android.app.Activity;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Bundle;
import android.os.Handler;
import android.os.Message;
import android.os.ParcelFileDescriptor;
import android.util.Log;

import android.widget.ImageView;
import android.widget.TextView;
import android.widget.SeekBar;
import android.widget.ToggleButton;
import android.widget.CompoundButton;
import android.graphics.drawable.Drawable;

import com.android.future.usb.UsbAccessory;
import com.android.future.usb.UsbManager;

import java.io.FileDescriptor;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;


public class DemoKitActivity extends Activity implements Runnable, SeekBar.OnSeekBarChangeListener, CompoundButton.OnCheckedChangeListener {
    private static final String TAG = "DemoKit";

    private static final String ACTION_USB_PERMISSION =
            "com.google.DemoKit.action.USB_PERMISSION";

    private UsbManager mUsbManager;
    private PendingIntent mPermissionIntent;
    private boolean mPermissionRequestPending;

    ParcelFileDescriptor mFileDescriptor;
    FileInputStream mInputStream;
    FileOutputStream mOutputStream;

    ImageView mButton1Image;
    ImageView mButton2Image;
    ImageView mButton3Image;

    SeekBar mLed1Red;
    SeekBar mLed1Green;
    SeekBar mLed1Blue;
    SeekBar mLed2Red;
    SeekBar mLed2Green;
    SeekBar mLed2Blue;
    SeekBar mLed3Red;
    SeekBar mLed3Green;
    SeekBar mLed3Blue;

    ToggleButton mRelay1Button;
    ToggleButton mRelay2Button;

    TextView mTemperature;
    TextView mLight;

    SeekBar mServo1;
    SeekBar mServo2;
    SeekBar mServo3;

    TextView mJoyX;
    TextView mJoyY;

    ImageView mCap;


    Drawable redball;
    Drawable greenball;

    private static final int MESSAGE_SWITCH = 1;
    private static final int MESSAGE_TEMPERATURE = 2;
    private static final int MESSAGE_LIGHT = 3;
    private static final int MESSAGE_JOY = 4;

    private class SwitchMsg {
        private byte sw;
        private byte state;
        public SwitchMsg(byte sw, byte state) {
            this.sw = sw;
            this.state = state;
        }

        public byte getSw() {
            return sw;
        }

        public byte getState() {
            return state;
        }
    }

    private class TemperatureMsg {
        private int temperature;

        public TemperatureMsg(int temperature) {
            this.temperature = temperature;
        }

        public int getTemperature() {
            return temperature;
        }
    }

    private class LightMsg {
        private int light;

        public LightMsg(int light) {
            this.light = light;
        }

        public int getLight() {
            return light;
        }
    }

    private class JoyMsg {
        private int x;
        private int y;

        public JoyMsg(int x, int y) {
            this.x = x;
            this.y = y;
        }

        public int getX() {
            return x;
        }

        public int getY() {
            return y;
        }
    }

   private final BroadcastReceiver mUsbReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            if (ACTION_USB_PERMISSION.equals(intent.getAction())) {
                synchronized (this) {
                    UsbAccessory accessory = UsbManager.getAccessory(intent);
                    if (intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)) {
                        openAccessory(accessory);
                    } else {
                        Log.d(TAG, "permission denied for accessory " + accessory);
                    }
                    mPermissionRequestPending = false;
                }
            }
        }
    };

    /** Called when the activity is first created. */
    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        mUsbManager = UsbManager.getInstance(this);
        mPermissionIntent = PendingIntent.getBroadcast(this, 0, new Intent(ACTION_USB_PERMISSION), 0);
        IntentFilter filter = new IntentFilter(ACTION_USB_PERMISSION);
        registerReceiver(mUsbReceiver, filter);

        setContentView(R.layout.main);

        mButton1Image = (ImageView)findViewById(R.id.button1Image);
        mButton2Image = (ImageView)findViewById(R.id.button2Image);
        mButton3Image = (ImageView)findViewById(R.id.button3Image);

        mLed1Red = (SeekBar)findViewById(R.id.led1Red);
        mLed1Red.setOnSeekBarChangeListener(this);
        mLed1Green = (SeekBar)findViewById(R.id.led1Green);
        mLed1Green.setOnSeekBarChangeListener(this);
        mLed1Blue = (SeekBar)findViewById(R.id.led1Blue);
        mLed1Blue.setOnSeekBarChangeListener(this);

        mLed2Red = (SeekBar)findViewById(R.id.led2Red);
        mLed2Red.setOnSeekBarChangeListener(this);
        mLed2Green = (SeekBar)findViewById(R.id.led2Green);
        mLed2Green.setOnSeekBarChangeListener(this);
        mLed2Blue = (SeekBar)findViewById(R.id.led2Blue);
        mLed2Blue.setOnSeekBarChangeListener(this);

        mLed3Red = (SeekBar)findViewById(R.id.led3Red);
        mLed3Red.setOnSeekBarChangeListener(this);
        mLed3Green = (SeekBar)findViewById(R.id.led3Green);
        mLed3Green.setOnSeekBarChangeListener(this);
        mLed3Blue = (SeekBar)findViewById(R.id.led3Blue);
        mLed3Blue.setOnSeekBarChangeListener(this);

        mRelay1Button = (ToggleButton)findViewById(R.id.relay1Button);
        mRelay1Button.setOnCheckedChangeListener(this);
        mRelay2Button = (ToggleButton)findViewById(R.id.relay2Button);
        mRelay2Button.setOnCheckedChangeListener(this);

        mTemperature = (TextView)findViewById(R.id.temperature);
        mLight = (TextView)findViewById(R.id.light);

        mServo1 = (SeekBar)findViewById(R.id.servo1);
        mServo1.setOnSeekBarChangeListener(this);
        mServo2 = (SeekBar)findViewById(R.id.servo2);
        mServo2.setOnSeekBarChangeListener(this);
        mServo3 = (SeekBar)findViewById(R.id.servo3);
        mServo3.setOnSeekBarChangeListener(this);

        mJoyX = (TextView)findViewById(R.id.joyX);
        mJoyY = (TextView)findViewById(R.id.joyY);

        mCap = (ImageView)findViewById(R.id.cap);

        redball =   getResources().getDrawable(R.drawable.redball);
        greenball = getResources().getDrawable(R.drawable.greenball);

    }

    @Override
    public void onResume() {
        super.onResume();

        Intent intent = getIntent();
        Log.d(TAG, "intent: " + intent);
        UsbAccessory[] accessories = mUsbManager.getAccessoryList();
        UsbAccessory accessory = (accessories == null ? null : accessories[0]);
        if (accessory != null) {
            if (mUsbManager.hasPermission(accessory)) {
                openAccessory(accessory);
            } else {
                synchronized (mUsbReceiver) {
                    if (!mPermissionRequestPending) {
                        mUsbManager.requestPermission(accessory, mPermissionIntent);
                        mPermissionRequestPending = true;
                    }
                }
            }
        } else {
            Log.d(TAG, "mAccessory is null");
        }
    }

    @Override
    public void onPause() {
        super.onPause();
        if (mFileDescriptor != null) {
            try {
                mFileDescriptor.close();
            } catch (IOException e) {
            } finally {
                mFileDescriptor = null;
            }
        }
    }

    @Override
    public void onDestroy() {
        unregisterReceiver(mUsbReceiver);
       super.onDestroy();
    }

    private void openAccessory(UsbAccessory accessory) {
        Log.d(TAG, "openAccessory: " + accessory);
        mFileDescriptor = mUsbManager.openAccessory(accessory);
        if (mFileDescriptor != null) {
            FileDescriptor fd = mFileDescriptor.getFileDescriptor();
            mInputStream = new FileInputStream(fd);
            mOutputStream = new FileOutputStream(fd);
            Thread thread = new Thread(null, this, "AccessoryChat");
            thread.start();
            Log.d(TAG, "openAccessory succeeded");
        } else {
            Log.d(TAG, "openAccessory fail");
        }
    }

    private int composeInt(byte hi, byte lo) {
        int val = (int)hi & 0xff;
        val *= 256;
        val += (int)lo & 0xff;
        return val;
    }

    public void run() {
        int ret = 0;
        byte[] buffer = new byte[16384];
        int i;

        while (ret >= 0) {
            try {
                ret = mInputStream.read(buffer);
            } catch (IOException e) {
                break;
            }

            Log.d(TAG, "got bytes " + ret);
            i = 0;
            while (i < ret) {
                int len = ret - i;

                switch (buffer[i]) {
                case 0x1:
                    if (len >= 3) {
                        Message m = Message.obtain(mHandler, MESSAGE_SWITCH);
                        m.obj = new SwitchMsg(buffer[i+1], buffer[i+2]);
                        mHandler.sendMessage(m);
                    }
                    i += 3;
                    break;

                case 0x4:
                    if (len >= 3) {
                        Message m = Message.obtain(mHandler, MESSAGE_TEMPERATURE);
                        m.obj = new TemperatureMsg(composeInt(buffer[i+1], buffer[i+2]));
                        mHandler.sendMessage(m);
                    }
                    i += 3;
                    break;

                case 0x5:
                    if (len >= 3) {
                        Message m = Message.obtain(mHandler, MESSAGE_LIGHT);
                        m.obj = new LightMsg(composeInt(buffer[i+1], buffer[i+2]));
                        mHandler.sendMessage(m);
                    }
                    i += 3;
                    break;

                case 0x6:
                    if (len >= 3) {
                        Message m = Message.obtain(mHandler, MESSAGE_JOY);
                        m.obj = new JoyMsg(buffer[i+1], buffer[i+2]);
                        mHandler.sendMessage(m);
                    }
                    i += 3;
                    break;

                default:
                    Log.d(TAG, "unknown msg: " + buffer[i]);
                    i = len;
                    break;
                }
            }

        }
        Log.d(TAG, "thread out");
    }

    Handler mHandler = new Handler() {
            @Override
            public void handleMessage(Message msg) {
                switch (msg.what) {
                case MESSAGE_SWITCH:
                    SwitchMsg o = (SwitchMsg)msg.obj;
                    if (o.getSw() == 0)
                        mButton1Image.setImageDrawable(o.getState() != 0 ? greenball : redball);
                    else if (o.getSw() == 1)
                        mButton2Image.setImageDrawable(o.getState() != 0 ? greenball : redball);
                    else if (o.getSw() == 2)
                        mButton3Image.setImageDrawable(o.getState() != 0 ? greenball : redball);
                    else if (o.getSw() == 3)
                        mCap.setImageDrawable(o.getState() != 0 ? greenball : redball);
                    break;

                case MESSAGE_TEMPERATURE:
                    TemperatureMsg t = (TemperatureMsg)msg.obj;
                    mTemperature.setText(String.format("%04x", t.getTemperature()));
                    break;

                case MESSAGE_LIGHT:
                    LightMsg l = (LightMsg)msg.obj;
                    mLight.setText(String.format("%04x", l.getLight()));
                    break;

                case MESSAGE_JOY:
                    JoyMsg j = (JoyMsg)msg.obj;
                    mJoyX.setText(String.format("%d", j.getX()));
                    mJoyY.setText(String.format("%d", j.getY()));
                    break;

                }
            }
        };

    public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
        byte[] buffer = new byte[3];
        if (progress > 255)
            progress = 255;

        buffer[0] = 0x2;
        buffer[1] = -1;
        buffer[2] = (byte) progress;

        if (seekBar == mLed1Red)
            buffer[1] = 0x0;
        else if (seekBar == mLed1Green)
            buffer[1] = 0x1;
        else if (seekBar == mLed1Blue)
            buffer[1] = 0x2;
        else if (seekBar == mLed2Red)
            buffer[1] = 0x3;
        else if (seekBar == mLed2Green)
            buffer[1] = 0x4;
        else if (seekBar == mLed2Blue)
            buffer[1] = 0x5;
        else if (seekBar == mLed3Red)
            buffer[1] = 0x6;
        else if (seekBar == mLed3Green)
            buffer[1] = 0x7;
        else if (seekBar == mLed3Blue)
            buffer[1] = 0x8;
        else if (seekBar == mServo1)
            buffer[1] = 0x10;
        else if (seekBar == mServo2)
            buffer[1] = 0x11;
        else if (seekBar == mServo3)
            buffer[1] = 0x12;

        if (buffer[1] != -1) {
            try {
                mOutputStream.write(buffer);
            } catch (IOException e) {
                Log.e(TAG, "write failed", e);
            }
        }

    }

    public void onStartTrackingTouch(SeekBar seekBar) {
    }

    public void onStopTrackingTouch(SeekBar seekBar) {
    }

    public void onCheckedChanged(CompoundButton buttonView, boolean isChecked) {
        byte[] buffer = new byte[3];
        buffer[0] = 0x3;
        buffer[1] = -1;
        buffer[2] = isChecked ? (byte)0x1 : (byte)0x0;

        if (buttonView == mRelay1Button)
            buffer[1] = 0;
        else if (buttonView == mRelay2Button)
            buffer[1] = 1;

        if (buffer[1] != -1) {
            try {
                mOutputStream.write(buffer);
            } catch (IOException e) {
                Log.e(TAG, "write failed", e);
            }
        }
    }
}

