package com.vnet.flutter_nfc_acs;

import android.Manifest;
import android.app.Activity;
import android.content.pm.PackageManager;
import android.os.Build;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import io.flutter.plugin.common.PluginRegistry.RequestPermissionsResultListener;

abstract class BluetoothPermissions implements RequestPermissionsResultListener {
  // A code we've defined, to identify the permission request.
  private static final int REQUEST_FINE_LOCATION_PERMISSIONS = 548351319;

  @Override
  public boolean onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
    if (android.os.Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {

      int bluetooth_scan_permission = ContextCompat.checkSelfPermission(getActivity().getApplicationContext(), Manifest.permission.BLUETOOTH_SCAN);
      int bluetooth_connect_permission = ContextCompat.checkSelfPermission(getActivity().getApplicationContext(), Manifest.permission.BLUETOOTH_CONNECT);
      if(bluetooth_scan_permission == PackageManager.PERMISSION_GRANTED && bluetooth_connect_permission == PackageManager.PERMISSION_GRANTED){
        afterPermissionsGranted();
      }else{
        afterPermissionsDenied();
      }
      return true;
    }else{
    if (requestCode == REQUEST_FINE_LOCATION_PERMISSIONS) {
      if (grantResults[0] == PackageManager.PERMISSION_GRANTED) {
        afterPermissionsGranted();
      } else {
        afterPermissionsDenied();
      }
      return true;
    }}

    return false;
  }

  void requestPermissions() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      ActivityCompat.requestPermissions(
          getActivity(),
          new String[]{
              Manifest.permission.BLUETOOTH_SCAN,
              Manifest.permission.BLUETOOTH_CONNECT,
              Manifest.permission.ACCESS_FINE_LOCATION
          },
          REQUEST_FINE_LOCATION_PERMISSIONS);
    } else {
      ActivityCompat.requestPermissions(
          getActivity(),
          new String[]{
              Manifest.permission.ACCESS_FINE_LOCATION
          },
          REQUEST_FINE_LOCATION_PERMISSIONS);
    }
  }

  boolean hasPermissions() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      return ContextCompat.checkSelfPermission(getActivity(), Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED &&
             ContextCompat.checkSelfPermission(getActivity(), Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED;
    } else {
      return ContextCompat.checkSelfPermission(getActivity(), Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED;
    }
  }

  protected abstract Activity getActivity();

  protected abstract void afterPermissionsGranted();

  protected abstract void afterPermissionsDenied();
}
