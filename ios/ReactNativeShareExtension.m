#import "ReactNativeShareExtension.h"
#import "DataItem.h"
#import "React/RCTRootView.h"
#import <MobileCoreServices/MobileCoreServices.h>

#define URL_IDENTIFIER @"public.url"
#define IMAGE_IDENTIFIER @"public.image"
#define TEXT_IDENTIFIER (NSString *)kUTTypePlainText

NSExtensionContext* extensionContext;

@implementation ReactNativeShareExtension {
    NSTimer *autoTimer;
    NSString* type;
    NSString* value;
}

- (UIView*) shareView {
    return nil;
}

RCT_EXPORT_MODULE();

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //object variable for extension doesn't work for react-native. It must be assign to gloabl
    //variable extensionContext. in this way, both exported method can touch extensionContext
    extensionContext = self.extensionContext;
    
    UIView *rootView = [self shareView];
    if (rootView.backgroundColor == nil) {
        rootView.backgroundColor = [[UIColor alloc] initWithRed:1 green:1 blue:1 alpha:0.1];
    }
    
    self.view = rootView;
}


RCT_EXPORT_METHOD(close) {
    [extensionContext completeRequestReturningItems:nil
                                  completionHandler:nil];
}



RCT_EXPORT_METHOD(openURL:(NSString *)url) {
    UIApplication *application = [UIApplication sharedApplication];
  NSURL *urlToOpen = [NSURL URLWithString:[url stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    [application openURL:urlToOpen options:@{} completionHandler: nil];
}



RCT_REMAP_METHOD(data,
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    [self extractDataFromContext: extensionContext withCallback:^(NSString* val, NSString* contentType, NSException* err) {
        if(err) {
            reject(@"error", err.description, nil);
        } else {
            resolve(@{
                      @"type": contentType,
                      @"value": val
                      });
        }
    }];
}

- (void)extractDataFromContext:(NSExtensionContext *)context withCallback:(void(^)(NSString *value, NSString* contentType, NSException *exception))callback {
    
    
    void (^processResults)(NSArray *) = ^void(NSArray *results) {
        for (DataItem *result in results) {
            NSLog(@"Result %@ Value: %@", result.contentType, result.value);
        }
        /* if(callback) {
         callback([url absoluteString], @"text/plain", nil);
         } */
        
        /* if(callback) {
         callback(fullPath, [fullPath pathExtension], nil);
         } */
    };
    
    @try {
        NSExtensionItem *item = [context.inputItems firstObject];
        NSArray *attachments = item.attachments;
        
        __block NSItemProvider *urlProvider = nil;
        __block NSItemProvider *imageProvider = nil;
        __block NSItemProvider *textProvider = nil;
        
        NSMutableArray *providers = [NSMutableArray array];
        
        [attachments enumerateObjectsUsingBlock:^(NSItemProvider *provider, NSUInteger idx, BOOL *stop) {
            if([provider hasItemConformingToTypeIdentifier:URL_IDENTIFIER]) {
                urlProvider = provider;
                [providers addObject:urlProvider];
            } else if ([provider hasItemConformingToTypeIdentifier:TEXT_IDENTIFIER]){
                textProvider = provider;
                [providers addObject:urlProvider];
            } else if ([provider hasItemConformingToTypeIdentifier:IMAGE_IDENTIFIER]){
                imageProvider = provider;
                [providers addObject:urlProvider];
            }
        }];
        
        
        NSInteger itemsCount = [providers count];
        __block NSMutableArray *results = [NSMutableArray array];
        
        
        if(urlProvider) {
            [urlProvider loadItemForTypeIdentifier:URL_IDENTIFIER options:nil completionHandler:^(id<NSSecureCoding> item, NSError *error) {
                NSURL *url = (NSURL *)item;
                DataItem *dataItem = [DataItem itemWithContentType:@"text/plain" value:[url absoluteString] exception:nil];
                [results addObject:dataItem];
                if(results.count == itemsCount) {
                    processResults(results);
                }
            }];
        } else if (imageProvider) {
            [imageProvider loadItemForTypeIdentifier:IMAGE_IDENTIFIER options:nil completionHandler:^(id<NSSecureCoding> item, NSError *error) {
                NSURL* url = (NSURL *)item;
                DataItem *dataItem = [DataItem itemWithContentType:[[[url absoluteString] pathExtension] lowercaseString] value:[url absoluteString]] exception:nil];
                [results addObject:dataItem];
                if(results.count == itemsCount) {
                    processResults(results);
                }
                
            }];
        } else if (textProvider) {
            [textProvider loadItemForTypeIdentifier:TEXT_IDENTIFIER options:nil completionHandler:^(id<NSSecureCoding> item, NSError *error) {
                NSString *text = (NSString *)item;
                DataItem *dataItem = [DataItem itemWithContentType:@"text/plain" value:text exception:nil];
                [results addObject:dataItem];
                if(results.count == itemsCount) {
                    processResults(results);
                }
            }];
        } else {
            if(callback) {
                callback(nil, nil, [NSException exceptionWithName:@"Error" reason:@"couldn't find provider" userInfo:nil]);
            }
        }
    }
    @catch (NSException *exception) {
        if(callback) {
            callback(nil, nil, exception);
        }
    }
}

+ (BOOL)requiresMainQueueSetup
{
  return NO;
}

@end
