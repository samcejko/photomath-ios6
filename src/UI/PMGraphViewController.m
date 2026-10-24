#import "PMSettings.h"
#import "PMGraphViewController.h"
#import "PMOfflineSolver.h"
#import "PMTheme.h"
#import "PMCommon.h"
#import "PMModern.h"
#import <QuartzCore/QuartzCore.h>
#import <math.h>

@interface PMGraphCanvas : UIView
@property(nonatomic,strong) PMGraphFunction *function;
@property(nonatomic) double centerX;
@property(nonatomic) double centerY;
@property(nonatomic) double halfRange;
@property(nonatomic) double startX;
@property(nonatomic) double startY;
@property(nonatomic) double startRange;
@end

static double PMGridStep(double span)
{
    double magnitude=pow(10,floor(log10(MAX(span/6,1e-12))));
    double step=span/6/magnitude;
    return (step<2?1:(step<5?2:5))*magnitude;
}

@implementation PMGraphCanvas
- (instancetype)initWithFrame:(CGRect)frame
{
    self=[super initWithFrame:frame];if(self){
        self.halfRange=10;self.backgroundColor=[UIColor whiteColor];self.clipsToBounds=YES;
        self.accessibilityLabel=L(@"Function graph");
        [self addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)]];
        [self addGestureRecognizer:[[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(pinch:)]];
    }return self;
}
- (void)pan:(UIPanGestureRecognizer *)gesture
{
    if(gesture.state==UIGestureRecognizerStateBegan){self.startX=self.centerX;self.startY=self.centerY;}
    if(self.bounds.size.height<=0)return;
    CGPoint delta=[gesture translationInView:self];double scale=2*self.halfRange/self.bounds.size.height;
    self.centerX=MAX(-1e9,MIN(1e9,self.startX-delta.x*scale));
    self.centerY=MAX(-1e9,MIN(1e9,self.startY+delta.y*scale));[self setNeedsDisplay];
}
- (void)pinch:(UIPinchGestureRecognizer *)gesture
{
    if(gesture.state==UIGestureRecognizerStateBegan)self.startRange=self.halfRange;
    if(gesture.scale>0 && isfinite(gesture.scale))self.halfRange=MAX(1e-5,MIN(1e6,self.startRange/gesture.scale));
    [self setNeedsDisplay];
}
- (void)drawRect:(CGRect)rect
{
    CGFloat width=self.bounds.size.width,height=self.bounds.size.height;
    if(width<2 || height<2 || !self.function)return;
    CGContextRef context=UIGraphicsGetCurrentContext();BOOL dark=[PMSettings shared].darkTheme;
    UIColor *background=dark?[UIColor colorWithWhite:.12 alpha:1]:[UIColor whiteColor];
    [background setFill];UIRectFill(self.bounds);
    double ySpan=2*self.halfRange,xSpan=ySpan*width/height;
    double minX=self.centerX-xSpan/2,minY=self.centerY-ySpan/2;
    double step=PMGridStep(ySpan);
    UIColor *grid=dark?[UIColor colorWithWhite:.25 alpha:1]:[UIColor colorWithWhite:.9 alpha:1];
    CGContextSetStrokeColorWithColor(context,grid.CGColor);CGContextSetLineWidth(context,.5);
    UIFont *font=[UIFont systemFontOfSize:10];
    UIColor *text=dark?[UIColor colorWithWhite:.7 alpha:1]:[UIColor colorWithWhite:.4 alpha:1];
    [text setFill];
    // Bounded iterations also protect extremely zoomed or panned views.
    for(NSInteger i=0;i<100;i++) {
        double x=(ceil(minX/step)+i)*step;if(x>minX+xSpan)break;
        CGFloat px=(x-minX)/xSpan*width;
        CGContextMoveToPoint(context,px,0);CGContextAddLineToPoint(context,px,height);
        CGFloat axisY=MAX(2,MIN(height-14,height-(0-minY)/ySpan*height+3));
        [[NSString stringWithFormat:@"%.4g",fabs(x)<step*1e-8?0:x] drawAtPoint:CGPointMake(px+2,axisY) withFont:font];
    }
    for(NSInteger i=0;i<100;i++) {
        double y=(ceil(minY/step)+i)*step;if(y>minY+ySpan)break;
        CGFloat py=height-(y-minY)/ySpan*height;
        CGContextMoveToPoint(context,0,py);CGContextAddLineToPoint(context,width,py);
        if(fabs(y)>step*1e-8) [[NSString stringWithFormat:@"%.4g",y] drawAtPoint:CGPointMake(MAX(2,MIN(width-42,(0-minX)/xSpan*width+3)),py+2) withFont:font];
    }
    CGContextStrokePath(context);
    CGContextSetStrokeColorWithColor(context,text.CGColor);CGContextSetLineWidth(context,1);
    CGFloat axisX=(0-minX)/xSpan*width,axisY=height-(0-minY)/ySpan*height;
    if(axisX>=0 && axisX<=width){CGContextMoveToPoint(context,axisX,0);CGContextAddLineToPoint(context,axisX,height);}
    if(axisY>=0 && axisY<=height){CGContextMoveToPoint(context,0,axisY);CGContextAddLineToPoint(context,width,axisY);}
    CGContextStrokePath(context);
    CGContextSetStrokeColorWithColor(context,[[PMTheme shared] accentColor].CGColor);CGContextSetLineWidth(context,2);
    NSInteger samples=MIN(600,MAX(100,(NSInteger)width));BOOL connected=NO;
    double previousX=0,previousY=0;
    for(NSInteger i=0;i<=samples;i++) {
        double x=minX+xSpan*i/samples,y=[self.function valueAtX:x];
        CGFloat px=(CGFloat)width*i/samples,py=height-(y-minY)/ySpan*height;
        BOOL valid=isfinite(y) && isfinite(py) && fabs(py)<height*100;
        BOOL bridge=valid && connected;
        if(bridge){
            double middle=[self.function valueAtX:(previousX+x)/2];
            // Never draw a line over a pole or a gap in the real domain.
            if(!isfinite(middle) || fabs(middle-(previousY+y)/2)>ySpan*.1 || fabs(y-previousY)>ySpan*2)bridge=NO;
        }
        if(valid){if(bridge)CGContextAddLineToPoint(context,px,py);else CGContextMoveToPoint(context,px,py);}
        connected=valid;previousX=x;previousY=y;
    }
    CGContextStrokePath(context);
}
@end

@interface PMGraphViewController ()
@property(nonatomic,strong) PMGraphFunction *function;
@property(nonatomic,strong) PMGraphCanvas *canvas;
@property(nonatomic,strong) UILabel *formulaLabel;
@property(nonatomic,strong) UILabel *hintLabel;
@property(nonatomic,strong) UIButton *zoomIn;
@property(nonatomic,strong) UIButton *zoomOut;
@property(nonatomic,strong) UIButton *reset;
@end
@implementation PMGraphViewController
- (instancetype)initWithFunction:(PMGraphFunction *)function
{
    self=[super init];if(self){_function=function;self.title=L(@"Graph");}return self;
}
- (UIButton *)button:(NSString *)title action:(SEL)action
{
    UIButton *button=[UIButton buttonWithType:UIButtonTypeCustom];[button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font=[UIFont boldSystemFontOfSize:15];
    [button setBackgroundImage:[[PMTheme shared] glossyButtonImageWithColor:[[PMTheme shared] accentColor] highlighted:NO] forState:UIControlStateNormal];
    [button setBackgroundImage:[[PMTheme shared] glossyButtonImageWithColor:[[PMTheme shared] accentColor] highlighted:YES] forState:UIControlStateHighlighted];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];[self.view addSubview:button];return button;
}
- (void)viewDidLoad
{
    [super viewDidLoad];self.view.backgroundColor=[[PMTheme shared] backgroundColor];
    self.formulaLabel=[[UILabel alloc] initWithFrame:CGRectZero];self.formulaLabel.backgroundColor=[UIColor clearColor];self.formulaLabel.font=[UIFont systemFontOfSize:13];self.formulaLabel.numberOfLines=2;self.formulaLabel.textColor=[[PMTheme shared] primaryTextColor];
    self.formulaLabel.text=[@"y = " stringByAppendingString:self.function.expression];[self.view addSubview:self.formulaLabel];
    self.canvas=[[PMGraphCanvas alloc] initWithFrame:CGRectZero];self.canvas.function=self.function;self.canvas.layer.cornerRadius=6;self.canvas.layer.borderWidth=1;self.canvas.layer.borderColor=[UIColor grayColor].CGColor;[self.view addSubview:self.canvas];
    self.hintLabel=[[UILabel alloc] initWithFrame:CGRectZero];self.hintLabel.backgroundColor=[UIColor clearColor];self.hintLabel.font=[UIFont systemFontOfSize:11];self.hintLabel.numberOfLines=2;self.hintLabel.textColor=self.formulaLabel.textColor;self.hintLabel.text=L(@"Drag to move. Pinch or use +/− to zoom. Gaps indicate undefined values.");[self.view addSubview:self.hintLabel];
    self.zoomIn=[self button:@"+" action:@selector(zoomInTapped)];self.zoomIn.accessibilityLabel=L(@"Zoom in");
    self.zoomOut=[self button:@"−" action:@selector(zoomOutTapped)];self.zoomOut.accessibilityLabel=L(@"Zoom out");self.reset=[self button:L(@"Reset") action:@selector(resetTapped)];
}
- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];CGRect bounds=self.view.bounds;UIEdgeInsets safe=PMSafeAreaInsets(self.view);
    CGFloat x=10+safe.left,width=bounds.size.width-x-10-safe.right,top=10+safe.top;
    self.formulaLabel.frame=CGRectMake(x,top,width,38);
    CGFloat bottom=bounds.size.height-safe.bottom;
    self.canvas.frame=CGRectMake(x,top+42,width,MAX(40,bottom-top-140));
    self.hintLabel.frame=CGRectMake(x,bottom-91,width,34);
    CGFloat third=(width-16)/3;self.zoomIn.frame=CGRectMake(x,bottom-50,third,40);self.zoomOut.frame=CGRectMake(x+third+8,bottom-50,third,40);self.reset.frame=CGRectMake(x+2*(third+8),bottom-50,third,40);[self.canvas setNeedsDisplay];
}
- (void)zoomInTapped { self.canvas.halfRange=MAX(1e-5,self.canvas.halfRange/1.5);[self.canvas setNeedsDisplay]; }
- (void)zoomOutTapped { self.canvas.halfRange=MIN(1e6,self.canvas.halfRange*1.5);[self.canvas setNeedsDisplay]; }
- (void)resetTapped { self.canvas.centerX=0;self.canvas.centerY=0;self.canvas.halfRange=10;[self.canvas setNeedsDisplay]; }
@end
