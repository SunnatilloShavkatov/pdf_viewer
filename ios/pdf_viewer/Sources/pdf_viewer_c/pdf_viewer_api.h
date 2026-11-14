// Hand-written Objective-C view of PdfViewerApi.swift. ffigen parses this file, so it must match the
// Swift signatures exactly (selectors, types, block signatures). A mismatch crashes at runtime.
// Keep it out of `include/`; it is only read by tool/ffigen.dart and compiled by the pod.
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PdfViewerApi : NSObject

+ (int32_t)openFile:(NSString *)path;
+ (int32_t)openBytes:(NSData *)data;
+ (int32_t)pageCount:(int32_t)docId;
+ (double)pageWidth:(int32_t)docId page:(int32_t)page;
+ (double)pageHeight:(int32_t)docId page:(int32_t)page;
+ (void)renderPage:(int32_t)docId
              page:(int32_t)page
             width:(int32_t)width
        completion:(void (^)(NSData *_Nullable data, NSString *_Nullable error))completion;
+ (void)textLayer:(int32_t)docId
             page:(int32_t)page
       completion:(void (^)(NSString *_Nullable json, NSString *_Nullable error))completion;
+ (void)close:(int32_t)docId;

@end

NS_ASSUME_NONNULL_END
