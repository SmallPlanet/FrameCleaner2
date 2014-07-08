//
//  SPDocument.h
//  FrameCleaner
//
//  Created by Quinn McHenry on 7/7/14.
//  Copyright (c) 2014 Small Planet. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SPDocument : NSDocument {
    CGRect globalFrame;
}

@property (nonatomic, strong) NSString *directoryPath;
@property (nonatomic, assign) BOOL shouldTrimImages;
@property (nonatomic, assign) BOOL removeDuplicateFrames;
@property (nonatomic, assign) BOOL compareWithMD5;


@property (nonatomic, strong) NSMutableArray *allFiles;
@property (nonatomic, strong) NSMutableArray *allImages;
@property (nonatomic, strong) IBOutlet NSMatrix *exportMatrix;
@property (assign) IBOutlet NSPopUpButton *maxSubregions;
@property (nonatomic, striog)IBOutlet NSImageView *imageView;

@end
