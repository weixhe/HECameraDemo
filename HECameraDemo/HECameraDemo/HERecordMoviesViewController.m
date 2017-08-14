//
//  HERecordMoviesViewController.m
//  HECameraDemo
//
//  Created by weixhe on 2017/8/10.
//  Copyright © 2017年 com.weixhe. All rights reserved.
//

#import "HERecordMoviesViewController.h"
#import "HECameraConstant.h"
#import "HERecordMoviesCell.h"
#import "HEVideos.h"
#import "HEMoviePlayerViewController.h"

#define key_title @"title"
#define key_thumb @"thumb"
#define key_path  @"path"
#define key_length @"length"

@interface HERecordMoviesViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray *dataSource;

@end

@implementation HERecordMoviesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT - 0) style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];
    [self.tableView registerClass:[HERecordMoviesCell class] forCellReuseIdentifier:@"HERecordMoviesCell"];
    
    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithImage:UIImageFromCameraBundle(@"icon-add") style:UIBarButtonItemStylePlain target:self action:@selector(onCreateMovieAction)];
    self.navigationItem.rightBarButtonItem = item;
    
    self.automaticallyAdjustsScrollViewInsets = YES;
    
    self.dataSource = [NSMutableArray array];
    [self loadData];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)loadData {
    // 如果没有自定义路径，则video保存路径直接取默认的
    
    NSArray *filesArray = [[NSFileManager defaultManager] subpathsAtPath:GetFilePath()];
    for (int i = 0; i < filesArray.count; i ++) {
        NSString *videoPath = [GetFilePath() stringByAppendingPathComponent:filesArray[i]];
        // 视频的title
        NSString *title = filesArray[i];
        
        // 此时video的第一针的图片地址可取
        NSString *cacheImagePath = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/he_videoThumb"];
        
        NSString *thumbPath = [cacheImagePath stringByAppendingFormat:@"/%@.jpg", [title stringByDeletingPathExtension]];
        
        [self.dataSource addObject:@{key_title:title, key_thumb:thumbPath, key_path:videoPath, key_length:@"2001"}];
    }
    
    
    if (self.dataSource.count > 0) {
        [self.tableView reloadData];
    }
}

- (void)onCreateMovieAction {
    HEVideos *camera = [[HEVideos alloc] init];
    __weak typeof(self) weakSelf = self;
    camera.BlockOnFinishRecorded = ^(UIImage *thumb, NSString *path) {
        NSString *title = [path lastPathComponent];
        NSString *thumbPath = nil;
        // 将 thumb 保存到缓存目录中，方便存取
        NSString *cacheImagePath = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/he_videoThumb"];
        BOOL isDir = NO;
        BOOL exist = [[NSFileManager defaultManager] fileExistsAtPath:cacheImagePath isDirectory:&isDir];
        if (!(isDir || exist)) {
            [[NSFileManager defaultManager] createDirectoryAtPath:cacheImagePath withIntermediateDirectories:YES attributes:nil error:nil];
        }
        NSData *data = UIImageJPEGRepresentation(thumb, 1);
        thumbPath = [NSString stringWithFormat:@"%@/%@.jpg", cacheImagePath, [title stringByDeletingPathExtension]];
        [data writeToFile:[NSString stringWithFormat:@"%@/%@.jpg", cacheImagePath, [title stringByDeletingPathExtension]] atomically:YES];
        
        
        [weakSelf.dataSource addObject:@{key_title:title, key_thumb:thumbPath, key_path:path, key_length:@"2001"}];
        [weakSelf.tableView reloadData];
    };
    [self presentViewController:camera animated:YES completion:nil];
}

#pragma mark - UITableViewDelegate UITabeViewDataSource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.dataSource.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 60;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    HERecordMoviesCell *cell = [tableView dequeueReusableCellWithIdentifier:@"HERecordMoviesCell"];
    
    cell.thumbImageView.image = [UIImage imageWithContentsOfFile:[[self.dataSource objectAtIndex:indexPath.row] objectForKey:key_thumb]];
    cell.titleLabel.text = [[self.dataSource objectAtIndex:indexPath.row] objectForKey:key_title];
    cell.subTitleLabel.text = [[self.dataSource objectAtIndex:indexPath.row] objectForKey:key_path];
    return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSDictionary *info = [self.dataSource objectAtIndex:indexPath.row];
    
    HEMoviePlayerViewController *moviePlayerVC = [[HEMoviePlayerViewController alloc] init];
    moviePlayerVC.moviePlaceholderPath = [info objectForKey:key_thumb];
    moviePlayerVC.movieTitle = [info objectForKey:key_title];
    moviePlayerVC.movieUrl = [info objectForKey:key_path];
    [self.navigationController pushViewController:moviePlayerVC animated:YES];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewCellEditingStyleDelete;
}

- (nullable NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
    return @"删除";
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        
        // 删除本地资源
        NSDictionary *info = [self.dataSource objectAtIndex:indexPath.row];
        [[NSFileManager defaultManager] removeItemAtPath:[info valueForKey:key_path] error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:[info valueForKey:key_thumb] error:nil];
        // 删除数据源
        [self.dataSource removeObjectAtIndex:indexPath.row];
        
        [tableView beginUpdates];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        [tableView endUpdates];
    }
}

@end
