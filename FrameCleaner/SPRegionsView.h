//
//  SPRegionsView.h
//  FrameCleaner
//
//  Created by Quinn McHenry on 7/9/14.
//  Copyright (c) 2014 Small Planet. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class SPDocument;
@class SPBorderedView;

@interface SPRegionsView : NSImageView {
    NSView *activeView;
    NSPoint originalOrigin;
}

@property (nonatomic, strong) NSMutableArray *regions;
@property (assign) SPDocument *document;

- (void)reset;
- (void) optimize;
- (NSArray *) regionsArrayForPlist;
- (void) setRegionsArrayFromPlist:(NSArray *)array;
- (void) addRegion:(SPBorderedView *)region;

@end
