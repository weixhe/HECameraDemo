//
//  HERecordMoviesCell.m
//  HECameraDemo
//
//  Created by weixhe on 2017/8/10.
//  Copyright © 2017年 com.weixhe. All rights reserved.
//

#import "HERecordMoviesCell.h"

@implementation HERecordMoviesCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        [self setup];
    }
    return self;
}

- (void)setup {
    self.thumbImageView = [[UIImageView alloc] initWithFrame:CGRectMake(10, 10, 40, 40)];
    [self.contentView addSubview:self.thumbImageView];
    
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(CGRectGetMaxX(self.thumbImageView.frame) + 10, 10, 200, 20)];
    self.titleLabel.font = [UIFont systemFontOfSize:13];
    self.titleLabel.textColor = [UIColor blackColor];
    [self.contentView addSubview:self.titleLabel];
    
    self.subTitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(CGRectGetMinX(self.titleLabel.frame), CGRectGetMaxY(self.titleLabel.frame), 200, 30)];
    self.subTitleLabel.font = [UIFont systemFontOfSize:11];
    self.subTitleLabel.textColor = [UIColor grayColor];
    [self.contentView addSubview:self.subTitleLabel];
    
}



- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

@end
