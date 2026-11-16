#import "../ios/ArdiaServices.h"
#import "../ios/ArdiaRuntime.h"
void WebKitWipePasswordBuffer(NSMutableData *data) { ardia_runtime::WipeSecret(data); }
