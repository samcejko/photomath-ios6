#import "PMStepCell.h"
#import "PMTheme.h"
#import "MTMathUILabel.h"
#import <QuartzCore/QuartzCore.h>

@interface PMStepCell ()
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UIImageView *badgeView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) MTMathUILabel *mathLabel;
@property (nonatomic, strong) UILabel *explanationLabel;
@end

@implementation PMStepCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = [UIColor clearColor];

        // Card container
        _cardView = [[UIView alloc] initWithFrame:CGRectZero];
        _cardView.layer.cornerRadius = 8.0f;
        _cardView.layer.borderWidth = 1.0f;
        [self.contentView addSubview:_cardView];

        // Step number badge
        _badgeView = [[UIImageView alloc] initWithFrame:CGRectMake(10, 10, 24, 24)];
        [_cardView addSubview:_badgeView];

        // Title
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.font = [UIFont boldSystemFontOfSize:14.0f];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.numberOfLines = 0;
        [_cardView addSubview:_titleLabel];

        // Math formula (iosMath LaTeX)
        _mathLabel = [[MTMathUILabel alloc] initWithFrame:CGRectZero];
        _mathLabel.labelMode = kMTMathUILabelModeDisplay;
        _mathLabel.fontSize = 18.0f;
        _mathLabel.textAlignment = kMTTextAlignmentLeft;
        [_cardView addSubview:_mathLabel];

        // Explanation text
        _explanationLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _explanationLabel.font = [UIFont systemFontOfSize:13.0f];
        _explanationLabel.backgroundColor = [UIColor clearColor];
        _explanationLabel.numberOfLines = 0;
        [_cardView addSubview:_explanationLabel];
    }
    return self;
}

- (void)configureWithStep:(PMStep *)step isDark:(BOOL)isDark
{
    self.cardView.backgroundColor = isDark ? [UIColor colorWithWhite:0.18f alpha:1.0f] : [UIColor whiteColor];
    self.cardView.layer.borderColor = isDark ? [UIColor colorWithWhite:0.28f alpha:1.0f].CGColor : [UIColor colorWithRed:0.86f green:0.88f blue:0.92f alpha:1.0f].CGColor;

    self.badgeView.image = [[PMTheme shared] circleBadgeImageWithNumber:step.stepNumber size:24.0f];

    self.titleLabel.textColor = isDark ? [UIColor whiteColor] : [UIColor colorWithRed:0.15f green:0.18f blue:0.24f alpha:1.0f];
    self.titleLabel.text = step.title;

    self.mathLabel.textColor = isDark ? [UIColor colorWithRed:0.95f green:0.95f blue:0.98f alpha:1.0f] : [UIColor colorWithRed:0.10f green:0.10f blue:0.15f alpha:1.0f];
    self.mathLabel.latex = step.latex.length ? step.latex : @"";

    self.explanationLabel.textColor = isDark ? [UIColor colorWithWhite:0.75f alpha:1.0f] : [UIColor colorWithRed:0.35f green:0.38f blue:0.45f alpha:1.0f];
    self.explanationLabel.text = step.explanation;

    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGFloat margin = 10.0f;
    CGFloat cardW = self.contentView.bounds.size.width - margin * 2;
    CGFloat cardX = margin;

    self.badgeView.frame = CGRectMake(12, 12, 24, 24);

    CGFloat titleX = CGRectGetMaxX(self.badgeView.frame) + 8.0f;
    CGFloat titleW = cardW - titleX - 12.0f;
    CGSize titleSz = [self.titleLabel.text sizeWithFont:self.titleLabel.font
                                      constrainedToSize:CGSizeMake(titleW, CGFLOAT_MAX)
                                          lineBreakMode:NSLineBreakByWordWrapping];
    self.titleLabel.frame = CGRectMake(titleX, 14, titleW, titleSz.height);

    CGFloat curY = MAX(CGRectGetMaxY(self.badgeView.frame), CGRectGetMaxY(self.titleLabel.frame)) + 8.0f;

    if (self.mathLabel.latex.length) {
        CGSize mathSz = [self.mathLabel sizeThatFits:CGSizeMake(cardW - 24.0f, CGFLOAT_MAX)];
        self.mathLabel.frame = CGRectMake(12, curY, cardW - 24.0f, MAX(28.0f, mathSz.height));
        self.mathLabel.hidden = NO;
        curY = CGRectGetMaxY(self.mathLabel.frame) + 6.0f;
    } else {
        self.mathLabel.hidden = YES;
    }

    if (self.explanationLabel.text.length) {
        CGSize expSz = [self.explanationLabel.text sizeWithFont:self.explanationLabel.font
                                              constrainedToSize:CGSizeMake(cardW - 24.0f, CGFLOAT_MAX)
                                                  lineBreakMode:NSLineBreakByWordWrapping];
        self.explanationLabel.frame = CGRectMake(12, curY, cardW - 24.0f, expSz.height);
        self.explanationLabel.hidden = NO;
        curY = CGRectGetMaxY(self.explanationLabel.frame) + 12.0f;
    } else {
        self.explanationLabel.hidden = YES;
        curY += 6.0f;
    }

    self.cardView.frame = CGRectMake(cardX, 6.0f, cardW, curY);
}

+ (CGFloat)heightForStep:(PMStep *)step width:(CGFloat)width isDark:(BOOL)isDark
{
    CGFloat cardW = width - 20.0f;
    CGFloat titleW = cardW - 44.0f;
    CGSize titleSz = [step.title sizeWithFont:[UIFont boldSystemFontOfSize:14.0f]
                            constrainedToSize:CGSizeMake(titleW, CGFLOAT_MAX)
                                lineBreakMode:NSLineBreakByWordWrapping];

    CGFloat h = 14.0f + titleSz.height + 8.0f;
    if (h < 40.0f) h = 40.0f;

    if (step.latex.length) {
        static MTMathUILabel *measuringLabel = nil;
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            measuringLabel = [[MTMathUILabel alloc] init];
            measuringLabel.labelMode = kMTMathUILabelModeDisplay;
            measuringLabel.fontSize = 18.0f;
        });
        measuringLabel.latex = step.latex;
        CGSize sz = [measuringLabel sizeThatFits:CGSizeMake(cardW - 24.0f, CGFLOAT_MAX)];
        h += MAX(36.0f, sz.height) + 8.0f;
    }

    if (step.explanation.length) {
        CGSize expSz = [step.explanation sizeWithFont:[UIFont systemFontOfSize:13.0f]
                                    constrainedToSize:CGSizeMake(cardW - 24.0f, CGFLOAT_MAX)
                                        lineBreakMode:NSLineBreakByWordWrapping];
        h += expSz.height + 12.0f;
    } else {
        h += 8.0f;
    }

    return h + 12.0f; // Card padding + margin
}

@end
