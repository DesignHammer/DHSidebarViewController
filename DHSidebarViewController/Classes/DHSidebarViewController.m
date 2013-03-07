//
//  DHSidebarViewController.m
//  ExerciseTimer
//
//  Created by Jay Roberts on 1/3/13.
//  Copyright (c) 2013 DesignHammer. All rights reserved.
//
//	Permission is hereby granted, free of charge, to any person obtaining a copy
//	of this software and associated documentation files (the "Software"), to deal
//	in the Software without restriction, including without limitation the rights to
//	use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
//	of the Software, and to permit persons to whom the Software is furnished to
//	do so, subject to the following conditions:
//
//	The above copyright notice and this permission notice shall be included in all
//	copies or substantial portions of the Software.
//
//	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
//	OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//	WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//	CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import "DHSidebarViewController.h"
#import "DHSidebarLayoutView.h"
#import <QuartzCore/QuartzCore.h>

#define kViewTagRoot 10000
#define kViewTagSidebar 10001

@interface DHSidebarViewController () {
    CGPoint _panOrigin;
    float _panStartingOffset;
    BOOL _sliding;
}

@property (nonatomic, strong) UIView* overlay;
@property (nonatomic, strong) UITapGestureRecognizer* tapGR;
@property (nonatomic, strong) UIViewController* overlayViewController;

@end

@implementation DHSidebarViewController

#pragma mark - Initialization

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (id)initWithRootViewController:(UIViewController*)rootViewController sidebarViewController:(UIViewController*)sidebarViewController {
    if ( (self = self = [super initWithNibName:nil bundle:nil]) ) {
        self.threshold = 50.0f;
        self.panningEnabled = YES;
        self.overlayColor = [UIColor blackColor];
        self.overlayOpacity = 0.2f;
        self.rootViewController = rootViewController;
        self.sidebarViewController = sidebarViewController;
        self.openOffset = 55.0f;
        _sliding = NO;
    }
    return self;
}

#pragma mark - View lifecycle

- (void) loadView {
    
    [super loadView];
    
    DHSidebarLayoutView * layoutView = [[DHSidebarLayoutView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame]];
    self.view = layoutView;
    self.overlay.frame = self.rootViewController.view.frame;
}

- (void) viewDidLoad {   
    [super viewDidLoad];
}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return [_rootViewController shouldAutorotateToInterfaceOrientation:interfaceOrientation];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    DHSidebarLayoutView* layoutView = (DHSidebarLayoutView*)self.view;
    layoutView.snapPosition = self.view.bounds.size.width - self.openOffset;
    self.overlay.frame = layoutView.bounds;
    
    if ([self isOpen]) {
        [self openSidebar];
    }
}

#pragma mark - DHSidebarViewController Public Methods

-(BOOL)isOpen {
    DHSidebarLayoutView* layoutView = (DHSidebarLayoutView*)self.view;
    float midpoint = layoutView.snapPosition / 2;
    return layoutView.offset > midpoint;
}

-(void)setOpenOffset:(float)openOffset {
    _openOffset = openOffset;
    DHSidebarLayoutView* layoutView = (DHSidebarLayoutView*)self.view;
    layoutView.snapPosition = self.view.bounds.size.width - self.openOffset;
}

- (void)setRootViewController:(UIViewController *)rootViewController {
    // Bail if null
    if (!rootViewController)  {
        return;
    }
    
    // Assign new controller
    UIViewController * oldRootViewController = _rootViewController;
    [oldRootViewController willMoveToParentViewController:nil];
    [oldRootViewController.view removeFromSuperview];
    [oldRootViewController removeFromParentViewController];
    
    _rootViewController = rootViewController;
    UIViewController * newRootViewController = rootViewController;
    
    [self addChildViewController:newRootViewController];
    newRootViewController.view.frame = self.view.bounds;
    
    // Set up tag for later retrieval
    newRootViewController.view.tag = kViewTagRoot;

    
    // Add left side drop shadow
    newRootViewController.view.layer.shadowOffset = CGSizeMake(-3, 0);
    newRootViewController.view.layer.shadowOpacity = 0.3f;
    
    // Set gesture recognizer for panning
    UIPanGestureRecognizer* panGR = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panned:)];
    panGR.delegate = self;
    panGR.cancelsTouchesInView = NO;
    [newRootViewController.view addGestureRecognizer:panGR];
    
    // Create overlay view
    if (self.overlay != nil) {
        [self.overlay removeFromSuperview];
    }
    self.overlay = [[UIView alloc] initWithFrame:newRootViewController.view.frame];
    self.overlay.backgroundColor = self.overlayColor;
    self.overlay.alpha = 0;
    
    // Create tap gesture reconizer for closing the rootView
    self.tapGR = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapped:)];
    
    if (!oldRootViewController) {
        [self.view addSubview:_rootViewController.view];
        [newRootViewController didMoveToParentViewController:self];
    } else {
        [self transitionFromViewController:oldRootViewController
                          toViewController:newRootViewController
                                  duration:1.0
                                   options:UIViewAnimationOptionTransitionNone
                                animations:^{
                                    
                                }
                                completion:^(BOOL completion) {
                                    [newRootViewController didMoveToParentViewController:self];
                                }
         ];
    }
}

- (void)setSidebarViewController:(UIViewController *)sidebarViewController {
    if (!sidebarViewController)  {
        return;
    }
    
    UIViewController * oldSidebarViewController = _sidebarViewController;
    [oldSidebarViewController willMoveToParentViewController:nil];
    [oldSidebarViewController.view removeFromSuperview];
    [oldSidebarViewController removeFromParentViewController];

    _sidebarViewController = sidebarViewController;
    UIViewController * newSidebarViewController = sidebarViewController;
    newSidebarViewController.view.frame = self.view.bounds;
    sidebarViewController.view.tag = kViewTagSidebar;

    // Set gesture recognizer
    if (!oldSidebarViewController) {
        [self.view insertSubview:_sidebarViewController.view atIndex:0];
        [newSidebarViewController didMoveToParentViewController:self];
    } else {
        [self transitionFromViewController:oldSidebarViewController
                          toViewController:newSidebarViewController
                                  duration:1.0
                                   options:UIViewAnimationOptionTransitionNone
                                animations:^{
                                    
                                }
                                completion:^(BOOL completion) {
                                    [newSidebarViewController didMoveToParentViewController:self];
                                }
         ];
    }
}

- (void)toggleSidebar {
    if (_sliding) {
        // Wait until open/close movement finsihes before allowing the state to be toggled
        return;
    }
    DHSidebarLayoutView* layoutView = (DHSidebarLayoutView*)self.view;
    float midpoint = layoutView.snapPosition / 2;
    if (layoutView.offset < midpoint) {
        [self openSidebar];
    } else {
        [self closeSidebar];
    }
}

- (void)openSidebar {
    DHSidebarLayoutView* layoutView = (DHSidebarLayoutView*)self.view;
    [layoutView setOffset:layoutView.snapPosition animated:YES];
    
    if ([self.overlay superview] != self.rootViewController.view) {
        [self.rootViewController.view addSubview:self.overlay];
        [self.rootViewController.view addGestureRecognizer:self.tapGR];
    }
    
    [UIView animateWithDuration:0.25
                     animations:^{
                         self.overlay.alpha = self.overlayOpacity;
                         _sliding = YES;
    }
                     completion:^(BOOL finished) {
                         _sliding = NO;
                     }];
}

- (void)closeSidebar {
    DHSidebarLayoutView* layoutView = (DHSidebarLayoutView*)self.view;
    [layoutView setOffset:0 animated:YES];
    
    [UIView animateWithDuration:0.25
                     animations:^{
                         self.overlay.alpha = 0;
                         _sliding = YES;
                     }
                     completion:^(BOOL finished) {
                         [self.overlay removeFromSuperview];
                         [self.rootViewController.view removeGestureRecognizer:self.tapGR];
                         _sliding = NO;
                     }];

}

- (void)hideRootViewController {
    DHSidebarLayoutView* layoutView = (DHSidebarLayoutView*)self.view;
    [layoutView setOffset:self.view.bounds.size.width animated:YES];
}

- (void)showRootViewController {
    [self openSidebar];
}

#pragma mark - UIGestureRecognizerDelegate

- (void) panned:(UIPanGestureRecognizer *)gr {

    switch (gr.state) {
        case UIGestureRecognizerStateBegan:
        {
            _panOrigin = [gr translationInView:self.view];
            DHSidebarLayoutView* layoutView = (DHSidebarLayoutView*)self.view;
            _panStartingOffset = layoutView.offset;
            break;
        }
        case UIGestureRecognizerStateChanged:
        {
            DHSidebarLayoutView* layoutView = (DHSidebarLayoutView*)self.view;

            CGPoint p = [gr translationInView:self.view];
            float distance = p.x - _panOrigin.x;
            
            if (self.panningEnabled) {
                layoutView.offset = _panStartingOffset + distance;
            }
            
            break;
        }
        case UIGestureRecognizerStateEnded:
        {
            DHSidebarLayoutView* layoutView = (DHSidebarLayoutView*)self.view;
            
            CGPoint p = [gr translationInView:self.view];
            float distance = p.x - _panOrigin.x;

            float snapPosition = self.threshold; // left side snap position
            if (distance < 0) { // right side snap position
                snapPosition = layoutView.snapPosition - self.threshold;
            }

            if (layoutView.offset < snapPosition) {
                [self closeSidebar]; // snap left
            } else {
                [self openSidebar]; // snap right
            }

            [UIView setAnimationDelegate:self];
            [UIView commitAnimations];
            
            break;
        }
        default:
            break;
    }
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    return YES;
}

- (void)tapped:(UITapGestureRecognizer *)gr {

    if ([self isOpen]) {
        [self closeSidebar];
    }
}

@end