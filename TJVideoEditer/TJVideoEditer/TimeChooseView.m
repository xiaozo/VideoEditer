//
//  TimeChooseView.m
//  TJVideoEditer
//
//  Created by TanJian on 17/2/13.
//  Copyright © 2017年 Joshpell. All rights reserved.
//

#import "TimeChooseView.h"
#import <AVFoundation/AVFoundation.h>
#import "TJMediaManager.h"


#define KendTimeButtonWidth self.bounds.size.width*0.5/3
#define KimageCount 15
#define KtotalTimeForSelf 15   //本页全长代表的视频时间



@interface WZScrollView : UIView

@property (nonatomic, strong) UIImage *image;
@property (nonatomic, assign) CGRect rect;

@property (strong, nonatomic) NSArray *images;
@property (assign, nonatomic) CGFloat width;


-(void)drawImage:(UIImage *)image inRect:(CGRect)rect;

@end

@implementation WZScrollView

-(void)drawRect:(CGRect)rect{
//    [super drawRect:_rect];
    
    [_image drawInRect:rect];
}

-(void)drawImage:(UIImage *)image inRect:(CGRect)rect{
    
    _image = image;
    _rect = rect;
    
    [self setNeedsDisplayInRect:rect];
}

@end

@interface WZScrollSubView : UIView

@property (nonatomic, strong) UIImage *image;

@end

@implementation WZScrollSubView

-(void)drawRect:(CGRect)rect{
    //    [super drawRect:_rect];
    
    if (_image) {
        [_image drawInRect:rect];
        _image = nil;
    }
    
}

-(void)drawImage:(UIImage *)image {
    _image = image;
    [self setNeedsDisplay];
}

@end
typedef enum {
    
    imageTypeStart,
    imageTypeEnd,
    
}imageType;


@interface TimeChooseView ()<UIScrollViewDelegate>

@property (nonatomic,strong) UIScrollView *scrollView;

@property (nonatomic,strong) UIImageView *startView;
@property (nonatomic,strong) UIImageView *endView;
@property (nonatomic,strong) UIView *topLine;
@property (nonatomic,strong) UIView *bottomLine;

@property (nonatomic,assign) CGFloat startTime;
@property (nonatomic,assign) CGFloat endTime;

@property (nonatomic,assign) CGFloat totalTime;

//正在操作开始或者结束指示器的类型
@property (nonatomic,assign) imageType chooseType;

@property (assign, nonatomic) CGFloat startEndViewMinDiffer;

@property (assign, nonatomic) CGFloat startEndViewMaxDiffer;

@property (nonatomic,strong) NSTimer *timer;                //计时器控制预览视频长度

@end


@implementation TimeChooseView

-(void)setupUI{
    
    
    _totalTime = [TJMediaManager getVideoTimeWithURL:self.videoURL];
    _startTime = 0;
    _endTime = KtotalTimeForSelf;
    
    self.scrollView = [[UIScrollView alloc]initWithFrame:self.bounds];
    _scrollView.delegate = self;
    _scrollView.bounces = NO;
    [self addSubview:_scrollView];
    
    //缩略图宽度
    UIImage *tempImage = [TJMediaManager getCoverImage:self.videoURL atTime:0 isKeyImage:NO];
    CGFloat width = tempImage.size.width*self.bounds.size.height/tempImage.size.height;
    
    //展示图片能看到的宽度
    CGFloat imageShowW = MIN(self.bounds.size.width*1.0f/7, width);
    
    //当前界面取KimageCount张图片展示15秒视频（取15张）
//    CGFloat timeUnit = KtotalTimeForSelf*1.0f/KimageCount;
//    NSInteger count = _totalTime/timeUnit;
    
    //180秒为一个单位 1.0 1.5 2.0的增长
    CGFloat timeUnit = (NSInteger)(_totalTime / 180) * 0.5 + 1.0;
    //有多少个缩略图
    NSInteger count = _totalTime/timeUnit;
    
    if (_totalTime - (NSInteger)_totalTime > 0) {
        //如果时间不是整数 获取最后一针图片
        count++;
    }
    _scrollView.contentSize = CGSizeMake(count*imageShowW, self.bounds.size.height);
    
    _startEndViewMaxDiffer = _scrollView.contentSize.width * (1.0 / 8);
    _startEndViewMinDiffer =  _scrollView.contentSize.width * (2.0 / _totalTime);
    if (_startEndViewMinDiffer > _startEndViewMaxDiffer) {
        _startEndViewMaxDiffer = _startEndViewMinDiffer;
    }
    
    WZScrollView *view = [[WZScrollView alloc]initWithFrame:CGRectMake(0,0,count*imageShowW, self.bounds.size.height)];
    [_scrollView addSubview:view];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        for (NSInteger i = 0; i<count; i++) {

//            dispatch_async(dispatch_get_main_queue(), ^{
//                [view drawImage:image inRect:CGRectMake(i*imageShowW, 0, width, self.bounds.size.height)];
//
//            });
            
            //循环多次创建uiimageview会导致内存暴涨，引起崩溃,解决：使用绘制把图片绘制到scrollview
            //            UIImageView *imageView = [[UIImageView alloc]initWithFrame:CGRectMake(i*imageShowW, 0, width, self.height)];
            //            imageView.image = image;
            
            //            dispatch_async(dispatch_get_main_queue(), ^{
            //                [_scrollView addSubview:imageView];
            //            });
            
            UIImage *image;
            if (count - 1 == i) {
                //
              image = [TJMediaManager getCoverImage:self.videoURL atTime:_totalTime isKeyImage:NO];
            } else {
              image = [TJMediaManager getCoverImage:self.videoURL atTime:timeUnit*i isKeyImage:NO];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                WZScrollSubView *imageView = [[WZScrollSubView alloc]initWithFrame:CGRectMake(i*imageShowW, 0, imageShowW,  self.bounds.size.height)];
                [view addSubview:imageView];
                [imageView drawImage:image];
            });

            
        }
        

    });
    
    //添加裁剪范围框
    self.startView = [[UIImageView alloc]initWithFrame:CGRectMake(0, 0, KendTimeButtonWidth, self.bounds.size.height)];
    _startView.image = [UIImage imageNamed:@"left"];
    _startView.tag = 99;
    UIPanGestureRecognizer * recognizer1 = [[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(panAction:)];
    recognizer1.maximumNumberOfTouches = 1;
    recognizer1.minimumNumberOfTouches = 1;
    [_startView addGestureRecognizer:recognizer1];
    [self.scrollView addSubview:_startView];
    self.startView.userInteractionEnabled = YES;
    
    CGFloat endViewX = MAX(MIN(CGRectGetMinX(self.startView.frame) + _startEndViewMaxDiffer - KendTimeButtonWidth, self.bounds.size.width-KendTimeButtonWidth), CGRectGetMinX(self.startView.frame) + _startEndViewMinDiffer - KendTimeButtonWidth);
    
    self.endView = [[UIImageView alloc]initWithFrame:CGRectMake(endViewX, 0, KendTimeButtonWidth, self.bounds.size.height)];
    _endView.image = [UIImage imageNamed:@"right"];
    _endView.tag = 100;
    UIPanGestureRecognizer * recognizer2 = [[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(panAction:)];
    recognizer2.maximumNumberOfTouches = 1;
    recognizer2.minimumNumberOfTouches = 1;
    [_endView addGestureRecognizer:recognizer2];
    [self.scrollView addSubview:_endView];
    self.endView.userInteractionEnabled = YES;
    
    self.topLine = [[UIView alloc]initWithFrame:CGRectMake(0, 0, self.bounds.size.width, 3)];
    _topLine.backgroundColor = [UIColor whiteColor];
    [self.scrollView addSubview:_topLine];
    
    self.bottomLine = [[UIView alloc]initWithFrame:CGRectMake(0, self.bounds.size.height-3,self.topLine.frame.size.width, 3)];
    _bottomLine.backgroundColor = [UIColor whiteColor];
    [self.scrollView addSubview:_bottomLine];
    
    //初始化
     [self calculateForTimeNodes];
}


//-(void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{

//    NSSet *allTouches = [event allTouches];    //返回与当前接收者有关的所有的触摸对象
//    NSArray *touchViews = [allTouches allObjects];
//    UITouch *touch = touchViews.firstObject;
//    CGPoint point = [touch locationInView:self];
//
//    if (point.x >= self.endView.x-20) {
//        self.chooseType = imageTypeEnd;
//
//    }else if(point.x <= self.startView.x + self.startView.width ){
//
//        self.chooseType = imageTypeStart;
//    }else{
//        return;
//    }
//
//    //取startView的x到endView的maxX为截取视频距离，下面计算以此为标准
//    switch (self.chooseType) {
//        case imageTypeEnd:
//        {
//            self.endView.frame = CGRectMake(point.x-KendTimeButtonWidth*0.5, 0,KendTimeButtonWidth, self.bounds.size.height);
//
//            if (self.endView.frame.origin.x+KendTimeButtonWidth-self.startView.frame.origin.x<=self.bounds.size.width/3.0f) {
//
//                self.endView.frame = CGRectMake(self.bounds.size.width*1/3.0f-KendTimeButtonWidth+self.startView.frame.origin.x, 0, KendTimeButtonWidth, self.bounds.size.height);
//            }else if(self.endView.frame.origin.x>self.bounds.size.width-KendTimeButtonWidth){
//
//                self.endView.frame = CGRectMake(self.bounds.size.width-KendTimeButtonWidth, 0, KendTimeButtonWidth, self.bounds.size.height);
//            }
//
//        }
//            break;
//        case imageTypeStart:
//        {
//            self.startView.frame = CGRectMake(point.x-KendTimeButtonWidth*0.5, 0,KendTimeButtonWidth, self.bounds.size.height);
//
//            if (self.startView.x <= 0) {
//
//                self.startView.frame = CGRectMake(0, 0, KendTimeButtonWidth, self.height);
//
//            }else if(self.startView.x >= self.endView.x+KendTimeButtonWidth-self.width/3.0f){
//
//                self.startView.frame = CGRectMake(self.endView.x+KendTimeButtonWidth-self.bounds.size.width/3.0f, 0, KendTimeButtonWidth, self.bounds.size.height);
//            }
//        }
//            break;
//        default:
//            break;
//    }
//
//    self.topLine.frame = CGRectMake(self.startView.frame.origin.x, 0, self.endView.frame.origin.x-self.startView.frame.origin.x + KendTimeButtonWidth, 3);
//    self.bottomLine.frame = CGRectMake(self.topLine.frame.origin.x, self.bounds.size.height-3, self.topLine.frame.size.width, 3);
//
//    //计算裁剪时间
//    [self calculateForTimeNodes];
//
//}


//
//-(void)panAction:(UIPanGestureRecognizer *)panGR{
//
//    UIView *view = panGR.view;
//    CGPoint P = [panGR translationInView:self.superview];
//    CGPoint oldOrigin = view.frame.origin;
//
//    switch (view.tag) {
//        case 99:
//        {
//            _chooseType = imageTypeStart;
//            if(oldOrigin.x+P.x <= CGRectGetMaxX(self.endView.frame)-self.bounds.size.width/3.0f && oldOrigin.x+P.x>=0){
//
//                view.frame = CGRectMake(oldOrigin.x+P.x, 0,KendTimeButtonWidth, self.bounds.size.height);
//            }
//        }
//            break;
//        case 100:
//        {
//            _chooseType = imageTypeEnd;
//            if (oldOrigin.x+P.x+KendTimeButtonWidth-self.startView.frame.origin.x>=self.bounds.size.width/3.0f && oldOrigin.x+P.x+KendTimeButtonWidth<=self.bounds.size.width) {
//
//                view.frame = CGRectMake(oldOrigin.x+P.x, 0,KendTimeButtonWidth, self.bounds.size.height);
//            }
//        }
//
//            break;
//        default:
//            break;
//    }
//
//    self.topLine.frame = CGRectMake(self.startView.frame.origin.x, 0, self.endView.frame.origin.x-self.startView.frame.origin.x + KendTimeButtonWidth, 3);
//    self.bottomLine.frame = CGRectMake(self.topLine.frame.origin.x, self.bounds.size.height-3, self.topLine.frame.size.width, 3);
//
//    if(panGR.state == UIGestureRecognizerStateChanged)
//    {
//        [panGR setTranslation:CGPointZero inView:self.superview];
//
//    }
//    //实时计算裁剪时间
//    [self calculateForTimeNodes];
//
//    if (panGR.state == UIGestureRecognizerStateEnded) {
//        if (self.cutWhenDragEnd) {
//            self.cutWhenDragEnd();
//        }
//    }
//}

////计算开始结束时间点
//-(void)calculateForTimeNodes{
//
//    CGPoint offset = _scrollView.contentOffset;
//
//    //可滚动范围分摊滚动范围代表的剩下时间
//    _startTime = (offset.x+self.startView.frame.origin.x)*KtotalTimeForSelf*1.0f/self.bounds.size.width;
//    _endTime = (offset.x + self.endView.frame.origin.x + KendTimeButtonWidth) * KtotalTimeForSelf * 1.0f/self.bounds.size.width;
//
//    //预览时间点
//    CGFloat imageTime = _startTime;
//    if (_chooseType == imageTypeEnd) {
//        imageTime = _endTime;
//    }
//
//
//    if (self.getTimeRange) {
//        self.getTimeRange(_startTime,_endTime,imageTime);
//    }
//}

-(void)panAction:(UIPanGestureRecognizer *)panGR{
    
    UIView *view = panGR.view;
    CGPoint P = [panGR translationInView:self.superview];
    switch (view.tag) {
        case 99:
        {
            _chooseType = imageTypeStart;
            [self updateStartEndViewPostion:P.x];
            
        }
            break;
        case 100:
        {
            _chooseType = imageTypeEnd;
            [self updateStartEndViewPostion:P.x];
        }
            
            break;
        default:
            break;
    }
    
    if(panGR.state == UIGestureRecognizerStateChanged)
    {
        [panGR setTranslation:CGPointZero inView:self.superview];
        
    }
    
    if (!_timer) {
        _timer = [NSTimer timerWithTimeInterval:0.1 target:self selector:@selector(timerAction) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:_timer forMode:NSDefaultRunLoopMode];
    }
   
    
    if (panGR.state == UIGestureRecognizerStateEnded) {
        if (self.cutWhenDragEnd) {
            self.cutWhenDragEnd();
        }
        
        
    }
    
    if (panGR.state != UIGestureRecognizerStateBegan && panGR.state != UIGestureRecognizerStateChanged) {
        if (_timer) {
            [_timer invalidate];
            _timer = nil;
        }
        _chooseType = -1;
    }
    
   
}

- (void)timerAction {
    NSLog(@"timerAction");
    if (self.scrollView.contentOffset.x < 0 || ((self.scrollView.contentSize.width - self.scrollView.frame.size.width) < self.scrollView.contentOffset.x)) {
        NSLog(@"stoptimerAction");
        return;
    }
    //负数为向左移动 正数为向右移动
    CGFloat changeValue = 0;
    CGPoint oldOrigin = _chooseType == imageTypeStart ? _startView.frame.origin : _endView.frame.origin;
    
    if (oldOrigin.x <= self.scrollView.contentOffset.x) {
        //移动距离 向左移动
        changeValue = MIN(self.scrollView.contentOffset.x, 5.0) * -1.0;
        self.scrollView.contentOffset = CGPointMake(self.scrollView.contentOffset.x + changeValue, 0);
        [self updateStartEndViewPostion: changeValue];
    } else if ((oldOrigin.x + KendTimeButtonWidth) >= (self.scrollView.contentOffset.x + self.scrollView.frame.size.width)) {
        //向右移动
        changeValue = MIN((self.scrollView.contentSize.width - self.scrollView.frame.size.width) - self.scrollView.contentOffset.x, 5.0);
        changeValue = MAX(changeValue, 0);
        self.scrollView.contentOffset = CGPointMake(self.scrollView.contentOffset.x + changeValue, 0);
        [self updateStartEndViewPostion: changeValue];
    }
}
//计算开始结束时间点
-(void)calculateForTimeNodes{
    
    self.topLine.frame = CGRectMake(self.startView.frame.origin.x, 0, self.endView.frame.origin.x-self.startView.frame.origin.x + KendTimeButtonWidth, 3);
    self.bottomLine.frame = CGRectMake(self.topLine.frame.origin.x, self.bounds.size.height-3, self.topLine.frame.size.width, 3);
    
    //可滚动范围分摊滚动范围代表的剩下时间
    _startTime = (self.startView.frame.origin.x) / self.scrollView.contentSize.width * _totalTime;
    _startTime = MAX(0, _startTime);
    
    _endTime = ( self.endView.frame.origin.x + KendTimeButtonWidth) / self.scrollView.contentSize.width * _totalTime;
    _endTime = MIN(_totalTime, _endTime);
    //预览时间点
    CGFloat imageTime = _startTime;
    if (_chooseType == imageTypeEnd) {
        imageTime = _endTime;
    }
    
    if (self.getTimeRange) {
        self.getTimeRange(_startTime,_endTime,imageTime);
    }
}

- (void)updateStartEndViewPostion:(CGFloat)changeValue {
    if (changeValue != 0) {
        UIView *view;
        if (_chooseType == imageTypeStart) {
            view = _startView;
             CGPoint oldOrigin = view.frame.origin;
            if (oldOrigin.x + changeValue <0 && oldOrigin.x > 0) {
                changeValue = oldOrigin.x * -1.0;
            }
            if(oldOrigin.x+changeValue <= CGRectGetMaxX(self.endView.frame)-_startEndViewMinDiffer
               && oldOrigin.x+changeValue >= CGRectGetMaxX(self.endView.frame)-_startEndViewMaxDiffer
               && oldOrigin.x+changeValue>=0){
                
                view.frame = CGRectMake(oldOrigin.x+changeValue, 0,KendTimeButtonWidth, self.bounds.size.height);
                
            } else {
                //判断是否需要平移
                CGPoint oldStartOrigin = _startView.frame.origin;
                CGPoint oldEndOrigin = _endView.frame.origin;
                if (oldStartOrigin.x+changeValue<0
                    || oldEndOrigin.x+changeValue+KendTimeButtonWidth > self.scrollView.contentSize.width) {
                    NSLog(@"已到达截取上限");
                    return;
                }
                //进行平移
                self.startView.frame = CGRectMake(oldStartOrigin.x+changeValue, 0,KendTimeButtonWidth, self.bounds.size.height);
                self.endView.frame = CGRectMake(oldEndOrigin.x+changeValue, 0,KendTimeButtonWidth, self.bounds.size.height);
            }
        } else if (_chooseType == imageTypeEnd) {
            view = _endView;
            CGPoint oldOrigin = view.frame.origin;
            
            if (oldOrigin.x+changeValue+KendTimeButtonWidth > self.scrollView.contentSize.width
                && oldOrigin.x +KendTimeButtonWidth < self.scrollView.contentSize.width) {
                changeValue = self.scrollView.contentSize.width - oldOrigin.x +KendTimeButtonWidth ;
            }
            if (oldOrigin.x+changeValue+KendTimeButtonWidth-self.startView.frame.origin.x>=_startEndViewMinDiffer
                && oldOrigin.x+changeValue+KendTimeButtonWidth-self.startView.frame.origin.x<=_startEndViewMaxDiffer
                && oldOrigin.x+changeValue+KendTimeButtonWidth<=self.scrollView.contentSize.width) {
                
                view.frame = CGRectMake(oldOrigin.x+changeValue, 0,KendTimeButtonWidth, self.bounds.size.height);
                
            } else {
                //判断是否需要平移
                 CGPoint oldStartOrigin = _startView.frame.origin;
                CGPoint oldEndOrigin = _endView.frame.origin;
                if (oldStartOrigin.x+changeValue<0
                    || oldEndOrigin.x+changeValue+KendTimeButtonWidth > self.scrollView.contentSize.width) {
                    NSLog(@"已到达截取上限");
                    return;
                }
                //进行平移
                self.startView.frame = CGRectMake(oldStartOrigin.x+changeValue, 0,KendTimeButtonWidth, self.bounds.size.height);
                self.endView.frame = CGRectMake(oldEndOrigin.x+changeValue, 0,KendTimeButtonWidth, self.bounds.size.height);
                
            }
        }
        //实时计算裁剪时间
        [self calculateForTimeNodes];
        
    }
 
}
#pragma mark scrollview代理

//-(void)scrollViewDidScroll:(UIScrollView *)scrollView{
//
//    _chooseType = imageTypeStart;
//    [self calculateForTimeNodes];
//
//}
//
//-(void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate{
//
//    if (self.cutWhenDragEnd) {
//        self.cutWhenDragEnd();
//    }
//}
//
//-(void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView{
//
//    if (self.cutWhenDragEnd) {
//        self.cutWhenDragEnd();
//    }
//
//}


@end
