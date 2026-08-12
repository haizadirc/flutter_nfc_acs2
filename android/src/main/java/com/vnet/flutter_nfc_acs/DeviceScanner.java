package com.vnet.flutter_nfc_acs;

import android.app.Activity;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.le.BluetoothLeScanner;
import android.bluetooth.le.ScanCallback;
import android.bluetooth.le.ScanResult;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.NonNull;

import java.util.HashMap;

import io.flutter.plugin.common.EventChannel.EventSink;
import io.flutter.plugin.common.EventChannel.StreamHandler;

import static android.content.ContentValues.TAG;
import static com.vnet.flutter_nfc_acs.FlutterNfcAcsPlugin.ERROR_NO_PERMISSIONS;

class DeviceScanner extends BluetoothPermissions implements StreamHandler {
  private HashMap<String, String> btDevices;
  private final BluetoothAdapter bluetoothAdapter;
  private EventSink events;
  private final Handler handler;
  private boolean scanning = false;
  private final Activity activity;

  private static final long SCAN_PERIOD = 10000;

  DeviceScanner(@NonNull BluetoothAdapter adapter, @NonNull Activity activity) {
    bluetoothAdapter = adapter;
    this.activity = activity;
    handler = new Handler(Looper.getMainLooper());
  }

  @Override
  public void onListen(Object arguments, EventSink events) {
    this.events = events;

    if (!hasPermissions()) {
      requestPermissions();
      return;
    }

    startScan();
  }

  @Override
  public void onCancel(Object arguments) {
    stopScan();
    events = null;
  }

  private final ScanCallback scanCallback = new ScanCallback() {
    @Override
    public void onScanResult(int callbackType, ScanResult result) {
      if (result == null || result.getDevice() == null) return;
      BluetoothDevice device = result.getDevice();
      String address = device.getAddress();
      String name = device.getName();

      if (events != null) {
        new Handler(Looper.getMainLooper()).post(() -> {
          if (btDevices != null && address != null) {
            boolean isNew = !btDevices.containsKey(address);
            btDevices.put(address, name != null ? name : "Unknown Device");
            if (isNew && events != null) {
              events.success(new HashMap<>(btDevices));
            }
          }
        });
      } else {
        Log.w(TAG, "Could not output devices, because the event sink was null");
      }
    }

    @Override
    public void onScanFailed(int errorCode) {
      Log.e(TAG, "BLE Scan failed with code: " + errorCode);
    }
  };

  private void startScan() {
    if (bluetoothAdapter == null || !bluetoothAdapter.isEnabled()) {
      Log.w(TAG, "BluetoothAdapter is disabled or null");
      return;
    }

    BluetoothLeScanner scanner = bluetoothAdapter.getBluetoothLeScanner();
    if (scanner == null) {
      Log.e(TAG, "BluetoothLeScanner is null");
      return;
    }

    btDevices = new HashMap<>();
    handler.postDelayed(() -> {
      if (scanning) {
        stopScan();
      }
    }, SCAN_PERIOD);

    scanning = true;
    try {
      scanner.startScan(scanCallback);
    } catch (SecurityException e) {
      Log.e(TAG, "SecurityException while starting scan", e);
    }
  }

  private void stopScan() {
    if (scanning && bluetoothAdapter != null && bluetoothAdapter.isEnabled()) {
      BluetoothLeScanner scanner = bluetoothAdapter.getBluetoothLeScanner();
      if (scanner != null) {
        try {
          scanner.stopScan(scanCallback);
        } catch (SecurityException e) {
          Log.e(TAG, "SecurityException while stopping scan", e);
        }
      }
    }
    scanning = false;
  }

  @Override
  protected Activity getActivity() {
    return activity;
  }

  @Override
  protected void afterPermissionsGranted() {
    if (bluetoothAdapter != null) {
      startScan();
    } else {
      Log.e(TAG, "Bluetooth adapter was null, in the permission callback");
    }
  }

  @Override
  protected void afterPermissionsDenied() {
    if (events != null) {
      events.error(ERROR_NO_PERMISSIONS, "Bluetooth and Location permissions are required", null);
      events = null;
    }
  }
}
