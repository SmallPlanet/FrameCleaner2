//
//  SPDocument.h
//  FrameCleaner
//
//  Created by Quinn McHenry on 7/7/14.
//  Copyright (c) 2014 Small Planet. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SPRegionsView.h"
#import "FCImage.h"

@interface SPDocument : NSDocument {
    CGRect globalFrame;
}

@property (nonatomic, strong) NSString *directoryPath;
@property (nonatomic, assign) BOOL shouldTrimImages;
@property (nonatomic, assign) BOOL compareWithMD5;
@property (nonatomic, strong) NSMutableData *subregionData;
@property (nonatomic, assign) CGSize imageSize;

@property (nonatomic, strong) NSMutableArray *allFiles;
@property (nonatomic, strong) NSMutableArray *allImages;
@property (nonatomic, strong) FCImage *firstImage;
@property (nonatomic, strong) IBOutlet NSMatrix *exportMatrix;
@property (nonatomic, strong) IBOutlet NSPopUpButton *maxSubregions;
@property (nonatomic, strong) IBOutlet NSImageView *imageView;
@property (nonatomic, strong) IBOutlet NSImageView *maskView;
@property (nonatomic, strong) IBOutlet SPRegionsView *regionsView;
@property (nonatomic, strong) IBOutlet NSView *mainView;
@property (nonatomic, strong) IBOutlet NSButton *removeDuplicateFrames;
@property (nonatomic, strong) IBOutlet NSPanel *progressPanel;
@property (nonatomic, strong) IBOutlet NSProgressIndicator *progressTopIndicator;
@property (nonatomic, strong) IBOutlet NSTextField *progressTopLabel;
@property (nonatomic, strong) IBOutlet NSProgressIndicator *progressIndicator;
@property (nonatomic, strong) IBOutlet NSTextField *progressLabel;
@property (nonatomic, strong) NSOperationQueue *queue;


@end
