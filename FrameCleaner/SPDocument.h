//
//  SPDocument.h
//  FrameCleaner
//
//  Created by Quinn McHenry on 7/7/14.
//  Copyright (c) 2014 Small Planet. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SPRegionsView.h"
#import "SPTimelineView.h"
#import "FCImage.h"

#define DEFAULT_FRAMERATE 12

@interface SPDocument : NSDocument {
    CGRect globalFrame;
    NSInteger playbackIndex;
    NSMutableArray *playbackCache;
}

@property (strong) NSString *directoryPath;
@property (assign) BOOL shouldTrimImages;
@property (assign) BOOL compareWithMD5;
@property (strong) NSMutableData *subregionData;
@property (assign) CGSize imageSize;
@property (strong) NSDictionary *settings;

@property (strong) NSMutableArray *allFiles;
@property (strong) NSMutableArray *allImages;
@property (strong) FCImage *firstImage;
@property (strong) IBOutlet NSMatrix *exportMatrix;
@property (strong) IBOutlet NSPopUpButton *maxSubregions;
@property (strong) IBOutlet NSImageView *imageView;
@property (strong) IBOutlet NSImageView *maskView;
@property (strong) IBOutlet SPRegionsView *regionsView;
@property (strong) IBOutlet NSView *mainView;
@property (strong) IBOutlet NSButton *removeDuplicateFrames;
@property (assign) IBOutlet SPTimelineView *timelineView;
@property (strong) IBOutlet NSButton *exportForImageBatch;

@property (strong) IBOutlet NSPanel *progressPanel;
@property (strong) IBOutlet NSProgressIndicator *progressTopIndicator;
@property (strong) IBOutlet NSTextField *progressTopLabel;
@property (strong) IBOutlet NSProgressIndicator *progressIndicator;
@property (strong) IBOutlet NSTextField *progressLabel;
@property (strong) IBOutlet NSTextField *framerateField;

@property (strong) NSOperationQueue *queue;
@property (strong) NSString *maskImageTmpFilename;
@property (strong) NSTimer *playbackTimer;

- (void) showFrameAtIndex:(NSInteger)index;
@end
