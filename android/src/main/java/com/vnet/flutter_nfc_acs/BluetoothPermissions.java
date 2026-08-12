package com.vnet.flutter_nfc_acs;

import android.Manifest;
import android.app.Activity;
import android.content.pm.PackageManager;
import android.os.Build;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import io.flutter.plugin.common.PluginRegistry.RequestPermissionsResultListener;

abstract class BluetoothPermissions implements RequestPermissionsResultListener {
  private static final int REQUEST_BLUETOOTH_PERMISSIONS = 548351319;

  @Override
  public boolean onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
    if (requestCode == REQUEST_BLUETOOTH_PERMISSIONS) {
      if (hasPermissions()) {
        afterPermissionsGranted();
      } else {
        afterPermissionsDenied();
      }
      return true;
    }
    return false;
  }

  void requestPermissions() {
    Activity activity = getActivity();
    if (activity == null) return;

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      ActivityCompat.requestPermissions(
          activity,
          new String[]{
              Manifest.permission.BLUETOOTH_SCAN,
              Manifest.permission.BLUETOOTH_CONNECT,
              Manifest.permission.ACCESS_FINE_LOCATION
          },
          REQUEST_BLUETOOTH_PERMISSIONS);
    } else {
      ActivityCompat.requestPermissions(
          activity,
          new String[]{
              Manifest.permission.ACCESS_FINE_LOCATION
          },
          REQUEST_BLUETOOTH_PERMISSIONS);
    }
  }

  boolean hasPermissions() {
    Activity activity = getActivity();
    if (activity == null) return false;

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      boolean scanOk = ContextCompat.checkSelfPermission(activity, Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED;
      boolean connectOk = ContextCompat.checkSelfPermission(activity, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED;
      return scanOk && connectOk;
    } else {
      return ContextCompat.checkSelfPermission(activity, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED;
    }
  }

  protected abstract Activity getActivity();

  protected abstract void afterPermissionsGranted();

  protected abstract void afterPermissionsDenied();
}
