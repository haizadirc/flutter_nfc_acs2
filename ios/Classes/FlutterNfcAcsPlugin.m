#import "FlutterNfcAcsPlugin.h"
#if __has_include(<flutter_nfc_acs2/flutter_nfc_acs2-Swift.h>)
#import <flutter_nfc_acs2/flutter_nfc_acs2-Swift.h>
#else
// Support project import headers when completed inside a framework target.
#import "flutter_nfc_acs2-Swift.h"
#endif

@implementation FlutterNfcAcsPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [FlutterNfcAcsPlugin registerWithRegistrar:registrar];
}
@end
