/* PlaybackViewController.m - Display currently-playing song info
 * Copyright (C) 2008 Sam Steele
 *
 * This file is part of MobileLastFM.
 *
 * MobileLastFM is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2
 * as published by the Free Software Foundation.
 *
 * MobileLastFM is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA
 */

#import <MediaPlayer/MediaPlayer.h>
#import "PlaybackViewController.h"
#import "MobileLastFMApplicationDelegate.h"
#import "ProfileViewController.h"
#import "UITableViewCell+ProgressIndicator.h"
#include "version.h"
#import "NSString+URLEscaped.h"
#import "UIViewController+NowPlayingButton.h"
#import "UIApplication+openURLWithWarning.h"
#import "NSString+MD5.h"

@implementation PlaybackSubview
- (void)enableLoveButton:(BOOL)enabled {
	_loveButton.enabled = enabled;
}
- (void)enableBanButton:(BOOL)enabled {
	_banButton.enabled = enabled;
}
- (void)backButtonPressed:(id)sender {
	if(self.navigationController == self.tabBarController.moreNavigationController)
		[self.tabBarController.moreNavigationController popViewControllerAnimated:YES];
	else
		[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) hidePlaybackView];
}
- (void)volumeButtonPressed:(id)sender {
	MPVolumeSettingsAlertShow();
}
@end

@implementation SimilarArtistsViewController
- (void)viewDidLoad {
	[super viewDidLoad];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_trackDidChange:) name:kLastFMRadio_TrackDidChange object:nil];
	_lock = [[NSLock alloc] init];
	_cells = [[NSMutableArray alloc] initWithCapacity:25];
}
- (void)viewWillAppear:(BOOL)animated {
	[_table scrollRectToVisible:[_table frame] animated:NO];
}
- (void)_trackDidChange:(NSNotification*)notification {
	[NSThread detachNewThreadSelector:@selector(_fetchSimilarArtists:) toTarget:self withObject:[notification userInfo]];
}
- (void)_fetchSimilarArtists:(NSDictionary *)trackInfo {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[_lock lock];
	[_data release];
	[_cells removeAllObjects];
	_data = [[LastFMService sharedInstance] artistsSimilarTo:[trackInfo objectForKey:@"creator"]];
	_data = [[_data subarrayWithRange:NSMakeRange(0,([_data count]>25)?25:[_data count])] retain];
	for(NSDictionary *artist in _data) {
		ArtworkCell *cell = [[ArtworkCell alloc] initWithFrame:CGRectZero reuseIdentifier:nil];
		cell.title.text = [artist objectForKey:@"name"];
		cell.barWidth = [[artist objectForKey:@"match"] floatValue] / 100.0f;
		cell.imageURL = [artist objectForKey:@"image_small"];
		[cell addStreamIcon];
		[_cells addObject:cell];
		[cell release];
	}
	[_table reloadData];
	[_table scrollRectToVisible:[_table frame] animated:YES];
	[self performSelectorOnMainThread:@selector(loadContentForCells:) withObject:[_table visibleCells] waitUntilDone:YES];
	[_lock unlock];
	[pool release];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [_data count];
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 48;
}
-(void)_playRadio:(NSTimer *)timer {
	if(![(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate hasNetworkConnection]) {
		[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate displayError:NSLocalizedString(@"ERROR_NONETWORK",@"No network available") withTitle:NSLocalizedString(@"ERROR_NONETWORK_TITLE",@"No network available title")];
	} else {
		[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate playRadioStation:[timer userInfo] animated:NO];
	}
}
-(void)playRadioStation:(NSString *)url {
	//Hack to make the loading throbber appear before we block
	[NSTimer scheduledTimerWithTimeInterval:0.1
																	 target:self
																 selector:@selector(_playRadio:)
																 userInfo:url
																	repeats:NO];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)newIndexPath {
	[[tableView cellForRowAtIndexPath: newIndexPath] showProgress:YES];
	[self playRadioStation:[NSString stringWithFormat:@"lastfm://artist/%@/similarartists", [[[_data objectAtIndex:[newIndexPath row]] objectForKey:@"name"] URLEscaped]]];
	[tableView deselectRowAtIndexPath:newIndexPath animated:YES];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	return [_cells objectAtIndex:[indexPath row]];
}
- (void)dealloc {
	[_data release];
	[super dealloc];
}
@end

@implementation TagsViewController
- (void)viewDidLoad {
	[super viewDidLoad];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_trackDidChange:) name:kLastFMRadio_TrackDidChange object:nil];
	_lock = [[NSLock alloc] init];
}
- (void)viewWillAppear:(BOOL)animated {
	[_table scrollRectToVisible:[_table frame] animated:NO];
}
- (void)_trackDidChange:(NSNotification*)notification {
	[NSThread detachNewThreadSelector:@selector(_fetchTags:) toTarget:self withObject:[notification userInfo]];
}
- (void)_fetchTags:(NSDictionary *)trackInfo {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[_lock lock];
	[_data release];
	_data = [[LastFMService sharedInstance] topTagsForTrack:[trackInfo objectForKey:@"title"] byArtist:[trackInfo objectForKey:@"creator"]];
	_data = [[_data subarrayWithRange:NSMakeRange(0,([_data count]>10)?10:[_data count])] retain];
	[_table reloadData];
	[_table scrollRectToVisible:[_table frame] animated:YES];
	[_lock unlock];
	[pool release];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [_data count];
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 48;
}
-(void)_playRadio:(NSTimer *)timer {
	if(![(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate hasNetworkConnection]) {
		[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate displayError:NSLocalizedString(@"ERROR_NONETWORK",@"No network available") withTitle:NSLocalizedString(@"ERROR_NONETWORK_TITLE",@"No network available title")];
	} else {
		[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate playRadioStation:[timer userInfo] animated:NO];
	}
}
-(void)playRadioStation:(NSString *)url {
	//Hack to make the loading throbber appear before we block
	[NSTimer scheduledTimerWithTimeInterval:0.1
																	 target:self
																 selector:@selector(_playRadio:)
																 userInfo:url
																	repeats:NO];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)newIndexPath {
	[[tableView cellForRowAtIndexPath: newIndexPath] showProgress:YES];
	[self playRadioStation:[NSString stringWithFormat:@"lastfm://globaltags/%@", [[[_data objectAtIndex:[newIndexPath row]] objectForKey:@"name"] URLEscaped]]];
	[tableView deselectRowAtIndexPath:newIndexPath animated:YES];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:nil] autorelease];
	cell.text = [[_data objectAtIndex:[indexPath row]] objectForKey:@"name"];
	float width = [[[_data objectAtIndex:[indexPath row]] objectForKey:@"count"] floatValue] / 100.0f;
	UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(0,0,width * [cell frame].size.width,48)];
	bar.backgroundColor = [UIColor colorWithWhite:0.8 alpha:0.4];
	[cell.contentView addSubview:bar];
	[bar release];
	UIImageView *img = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"streaming.png"]];
	cell.accessoryView = img;
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	[img release];
	return cell;
}
- (void)dealloc {
	[_data release];
	[super dealloc];
}
@end

@implementation FansViewController
- (void)viewDidLoad {
	[super viewDidLoad];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_trackDidChange:) name:kLastFMRadio_TrackDidChange object:nil];
	_lock = [[NSLock alloc] init];
	_cells = [[NSMutableArray alloc] init];
}
- (void)viewWillAppear:(BOOL)animated {
	[_table scrollRectToVisible:[_table frame] animated:NO];
}
- (void)_trackDidChange:(NSNotification*)notification {
	[NSThread detachNewThreadSelector:@selector(_fetchFans:) toTarget:self withObject:[notification userInfo]];
}
- (void)_fetchFans:(NSDictionary *)trackInfo {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[_lock lock];
	[_data release];
	[_cells removeAllObjects];
	_data = [[LastFMService sharedInstance] fansOfTrack:[trackInfo objectForKey:@"title"] byArtist:[trackInfo objectForKey:@"creator"]];
	_data = [[_data subarrayWithRange:NSMakeRange(0,([_data count]>10)?10:[_data count])] retain];
	for(NSDictionary *fan in _data) {
		ArtworkCell *cell = [[ArtworkCell alloc] initWithFrame:CGRectZero reuseIdentifier:nil];
		cell.title.text = [fan objectForKey:@"username"];
		cell.imageURL = [fan objectForKey:@"image"];
		[_cells addObject:cell];
		[cell release];
	}
	[_table reloadData];
	[_table scrollRectToVisible:[_table frame] animated:YES];
	[self performSelectorOnMainThread:@selector(loadContentForCells:) withObject:[_table visibleCells] waitUntilDone:YES];
	[_lock unlock];
	[pool release];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [_data count];
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 48;
}
-(void)_showProfile:(NSTimer *)timer {
	ProfileViewController *profileViewController = [[ProfileViewController alloc] initWithUsername:[timer userInfo]];
	[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate).navController pushViewController:profileViewController animated:NO];
	[profileViewController release];
	[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) hidePlaybackView];
	[_table reloadData];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)newIndexPath {
	[[tableView cellForRowAtIndexPath: newIndexPath] showProgress:YES];
	[NSTimer scheduledTimerWithTimeInterval:0.1
																	 target:self
																 selector:@selector(_showProfile:)
																 userInfo:[[_data objectAtIndex:[newIndexPath row]] objectForKey:@"username"]
																	repeats:NO];
	[tableView deselectRowAtIndexPath:newIndexPath animated:YES];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	return [_cells objectAtIndex:[indexPath row]];
}
- (void)dealloc {
	[_data release];
	[super dealloc];
}
@end

@implementation TrackViewController
- (void)viewDidLoad {
	[super viewDidLoad];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_trackDidChange:) name:kLastFMRadio_TrackDidChange object:nil];
	[NSTimer scheduledTimerWithTimeInterval:0.5
																	 target:self
																 selector:@selector(_updateProgress:)
																 userInfo:nil
																	repeats:YES];
}
- (NSString *)formatTime:(int)seconds {
	if(seconds <= 0)
		return @"0:00";
	int h = seconds / 3600;
	int m = (seconds%3600) / 60;
	int s = seconds%60;
	if(h)
		return [NSString stringWithFormat:@"%i:%02i:%02i", h, m, s];
	else
		return [NSString stringWithFormat:@"%i:%02i", m, s];
}
- (void)_updateProgress:(NSTimer *)timer {
	if([[LastFMRadio sharedInstance] state] != RADIO_IDLE) {
		float duration = [[[[LastFMRadio sharedInstance] trackInfo] objectForKey:@"duration"] floatValue]/1000.0f;
		float elapsed = [[LastFMRadio sharedInstance] trackPosition];

		_progress.progress = elapsed / duration;
		_elapsed.text = [self formatTime:elapsed];
		_remaining.text = [NSString stringWithFormat:@"-%@",[self formatTime:duration-elapsed]];
		_bufferPercentage.text = [NSString stringWithFormat:@"%i%%", (int)([[LastFMRadio sharedInstance] bufferProgress] * 100.0f)];
	}
	if([[LastFMRadio sharedInstance] state] == RADIO_BUFFERING && _bufferingView.alpha < 1) {
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationDuration:0.5];
		_bufferingView.alpha = 1;
		[UIView commitAnimations];
	}
	if([[LastFMRadio sharedInstance] state] == RADIO_BUFFERING && _bufferingView.alpha == 1 && _bufferPercentage.alpha < 1) {
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationDuration:10];
		_bufferPercentage.alpha = 1;
		[UIView commitAnimations];
	}
	if([[LastFMRadio sharedInstance] state] != RADIO_BUFFERING && _bufferingView.alpha == 1) {
		_bufferPercentage.alpha = 0;
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationDuration:0.5];
		_bufferingView.alpha = 0;
		[UIView commitAnimations];
	}
}
- (void)_fetchArtwork:(NSDictionary *)trackInfo {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSDictionary *albumData = [[LastFMService sharedInstance] metadataForAlbum:[trackInfo objectForKey:@"album"] byArtist:[trackInfo objectForKey:@"creator"] inLanguage:[[[NSUserDefaults standardUserDefaults] objectForKey: @"AppleLanguages"] objectAtIndex:0]];
	if([LastFMService sharedInstance].error && [LastFMService sharedInstance].error.code != 8) {
		[((MobileLastFMApplicationDelegate *)([UIApplication sharedApplication].delegate)) reportError:[LastFMService sharedInstance].error];
	}
	NSString *artwork = nil;
	UIImage *artworkImage;
	
	if([[albumData objectForKey:@"image"] length]) {
		artwork = [NSString stringWithString:[albumData objectForKey:@"image"]];
	} else if([[trackInfo objectForKey:@"image"] length]) {
			artwork = [NSString stringWithString:[trackInfo objectForKey:@"image"]];
	}

	if(!artwork || [artwork isEqualToString:@"http://cdn.last.fm/depth/catalogue/noimage/cover_med.gif"] || [artwork isEqualToString:@"http://cdn.last.fm/depth/catalogue/noimage/cover_large.gif"]) {
		NSDictionary *artistData = [[LastFMService sharedInstance] metadataForArtist:[trackInfo objectForKey:@"creator"] inLanguage:[[[NSUserDefaults standardUserDefaults] objectForKey: @"AppleLanguages"] objectAtIndex:0]];
		if([artistData objectForKey:@"image"])
			artwork = [NSString stringWithString:[artistData objectForKey:@"image"]];
	}
	
	NSLog(@"Loading artwork: %@\n", artwork);
	if(artwork && ![artwork isEqualToString:@"http://cdn.last.fm/depth/catalogue/noimage/cover_med.gif"] && ![artwork isEqualToString:@"http://cdn.last.fm/depth/catalogue/noimage/cover_large.gif"]) {
		NSData *imageData = [[NSData alloc] initWithContentsOfURL:[NSURL URLWithString: artwork]];
		artworkImage = [[UIImage alloc] initWithData:imageData];
		[imageData release];
	} else {
		artwork = [NSString stringWithFormat:@"file:///%@/noartplaceholder.png", [[NSBundle mainBundle] bundlePath]];
		artworkImage = [[UIImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"noartplaceholder" ofType:@"png"]];
	}

	_artworkView.image = artworkImage;
	[artworkImage release];
	[pool release];
}
- (void)_trackDidChange:(NSNotification *)notification {
	NSDictionary *trackInfo = [notification userInfo];
	
	_trackTitle.text = [trackInfo objectForKey:@"title"];
	_artist.text = [trackInfo objectForKey:@"creator"];
	_album.text = [trackInfo objectForKey:@"album"];
	_elapsed.text = @"0:00";
	_remaining.text = [NSString stringWithFormat:@"-%@",[self formatTime:([[trackInfo objectForKey:@"duration"] floatValue] / 1000.0f)]];
	_progress.progress = 0;
	_artworkView.image = [UIImage imageNamed:@"noartplaceholder.png"];

	_station.text = [[[LastFMRadio sharedInstance] station] capitalizedString];
	[self _updateProgress:nil];

	[NSThread detachNewThreadSelector:@selector(_fetchArtwork:) toTarget:self withObject:[notification userInfo]];
}
- (void)buyButtonPressed:(id)sender {
	[[UIApplication sharedApplication] openURLWithWarning:[NSURL URLWithString:[NSString stringWithFormat:@"itms://ax.phobos.apple.com.edgesuite.net/WebObjects/MZSearch.woa/wa/search?term=%@+%@", 
																							[_artist.text URLEscaped],
																							[_trackTitle.text URLEscaped]
																							]]];
}
- (void)shareToAddressBook {
	ABPeoplePickerNavigationController *peoplePicker = [[ABPeoplePickerNavigationController alloc] init];
	peoplePicker.displayedProperties = [NSArray arrayWithObjects:[NSNumber numberWithInteger:kABPersonEmailProperty], nil];
	peoplePicker.peoplePickerDelegate = self;
	[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate).playbackViewController presentModalViewController:peoplePicker animated:YES];
	[peoplePicker release];
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
}
- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker shouldContinueAfterSelectingPerson:(ABRecordRef)person {
	return YES;
}
- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker shouldContinueAfterSelectingPerson:(ABRecordRef)person property:(ABPropertyID)property identifier:(ABMultiValueIdentifier)identifier {
	NSString *email = (NSString *)ABMultiValueCopyValueAtIndex(ABRecordCopyValue(person, property), ABMultiValueGetIndexForIdentifier(ABRecordCopyValue(person, property), identifier));
	[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate).playbackViewController dismissModalViewControllerAnimated:YES];
	
	[[LastFMService sharedInstance] recommendTrack:_trackTitle.text
																				byArtist:_artist.text
																	toEmailAddress:email];
	
	if([LastFMService sharedInstance].error)
		[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) reportError:[LastFMService sharedInstance].error];
	else
		[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) displayError:NSLocalizedString(@"SHARE_SUCCESSFUL", @"Share successful") withTitle:NSLocalizedString(@"SHARE_SUCCESSFUL_TITLE", @"Share successful title")];
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:YES];
	return NO;
}
- (void)peoplePickerNavigationControllerDidCancel:(ABPeoplePickerNavigationController *)peoplePicker {
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:YES];
	[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate).playbackViewController dismissModalViewControllerAnimated:YES];
}
- (void)shareToFriend {
	FriendsViewController *friends = [[FriendsViewController alloc] initWithUsername:[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"]];
	if(friends) {
		friends.delegate = self;
		friends.title = @"Choose A Friend";
		UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:friends];
		[friends release];
		[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate).playbackViewController presentModalViewController:nav animated:YES];
		[nav release];
		[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
	}
}
- (void)friendsViewController:(FriendsViewController *)friends didSelectFriend:(NSString *)username {
	[[LastFMService sharedInstance] recommendTrack:_trackTitle.text
																				byArtist:_artist.text
																	toEmailAddress:username];
	if([LastFMService sharedInstance].error)
		[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) reportError:[LastFMService sharedInstance].error];
	else
		[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) displayError:NSLocalizedString(@"SHARE_SUCCESSFUL", @"Share successful") withTitle:NSLocalizedString(@"SHARE_SUCCESSFUL_TITLE", @"Share successful title")];
	
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:YES];
	[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate).playbackViewController dismissModalViewControllerAnimated:YES];
}
- (void)friendsViewControllerDidCancel:(FriendsViewController *)friends {
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:YES];
	[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate).playbackViewController dismissModalViewControllerAnimated:YES];
}
-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
	switch(buttonIndex) {
		case 0:
			[self shareToAddressBook];
			break;
		case 1:
			[self shareToFriend];
			break;
	}
}
- (void)shareButtonPressed:(id)sender {
	UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Who would you like to share this track with?", @"Share sheet title")
																										 delegate:self
																						cancelButtonTitle:NSLocalizedString(@"Cancel", @"Cancel")
																			 destructiveButtonTitle:nil
																						otherButtonTitles:NSLocalizedString(@"Contacts", @"Share to Address Book"), NSLocalizedString(@"Last.fm Friends", @"Share to Last.fm friend"), nil];
	[sheet showInView:self.tabBarController.view];
	[sheet release];	
}
@end

@implementation ArtistBioView
- (void)viewDidLoad {
	[super viewDidLoad];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_trackDidChange:) name:kLastFMRadio_TrackDidChange object:nil];
	_lock = [[NSLock alloc] init];
}
- (void)viewWillAppear:(BOOL)animated {
	[self refresh];
}
- (void)_trackDidChange:(NSNotification*)notification {
	[NSThread detachNewThreadSelector:@selector(_fetchBio:) toTarget:self withObject:[notification userInfo]];
}
- (void)_fetchBio:(NSDictionary *)trackInfo {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[_lock lock];
	[_bio release];
	_bar.topItem.title = [trackInfo objectForKey:@"creator"];
	NSString *bio = [[[LastFMService sharedInstance] metadataForArtist:[trackInfo objectForKey:@"creator"] inLanguage:[[[NSUserDefaults standardUserDefaults] objectForKey: @"AppleLanguages"] objectAtIndex:0]] objectForKey:@"bio"];
	if(![bio length]) {
		bio = [[[LastFMService sharedInstance] metadataForArtist:[trackInfo objectForKey:@"creator"] inLanguage:@"en"] objectForKey:@"bio"];
	}
	if(![bio length]) {
		bio = NSLocalizedString(@"No artist description available.", @"Wiki text empty");
	}

	_bio = [[bio stringByReplacingOccurrencesOfString:@"\n" withString:@"<br/>"] retain];
	[self performSelectorOnMainThread:@selector(refresh) withObject:nil waitUntilDone:YES];
	[_lock unlock];
	[pool release];
}
- (void)refresh {
	NSString *html = [NSString stringWithFormat:@"<html>\
										<body style=\"margin:0; padding:0; color:black; background: white; font-family: 'Lucida Grande', Arial; line-height: 1.2em;\">\
										<div style=\"padding:12px; margin:0; top:0px; left:0px; width:260px; position:absolute;\">\
										%@</div></body></html>", _bio];
	[_webView loadHTMLString:html baseURL:nil];
}
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
	NSURL *loadURL = [[request URL] retain];
	if(([[loadURL scheme] isEqualToString: @"http"] || [[loadURL scheme] isEqualToString: @"https"]) && (navigationType == UIWebViewNavigationTypeLinkClicked)) {
		[[UIApplication sharedApplication] openURLWithWarning:[loadURL autorelease]];
		return NO;
	}
	[loadURL release];
	return YES;
}
@end

@implementation EventCell
- (id)initWithFrame:(CGRect)frame reuseIdentifier:(NSString *)identifier {
	if (self = [super initWithFrame:frame reuseIdentifier:identifier]) {
		_title = [[UILabel alloc] init];
		_title.textColor = [UIColor blackColor];
		_title.highlightedTextColor = [UIColor whiteColor];
		_title.backgroundColor = [UIColor clearColor];
		_title.font = [UIFont boldSystemFontOfSize:18];
		[self.contentView addSubview:_title];

		_venue = [[UILabel alloc] init];
		_venue.textColor = [UIColor blackColor];
		_venue.highlightedTextColor = [UIColor whiteColor];
		_venue.backgroundColor = [UIColor clearColor];
		_venue.font = [UIFont systemFontOfSize:16];
		[self.contentView addSubview:_venue];

		_location = [[UILabel alloc] init];
		_location.textColor = [UIColor blackColor];
		_location.highlightedTextColor = [UIColor whiteColor];
		_location.backgroundColor = [UIColor clearColor];
		_location.font = [UIFont systemFontOfSize:16];
		[self.contentView addSubview:_location];
	}
	return self;
}
- (void)setEvent:(NSDictionary *)event {
	_title.text = [event objectForKey:@"title"];
	_venue.text = [event objectForKey:@"venue"];
	_location.text = [NSString stringWithFormat:@"%@, %@", [event objectForKey:@"city"], NSLocalizedString([event objectForKey:@"country"], @"Country name")];
}
- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
	[super setSelected:selected animated:animated];
	_title.highlighted = selected;
	_venue.highlighted = selected;
	_location.highlighted = selected;
}
- (void)layoutSubviews {
	[super layoutSubviews];
	
	CGRect frame = [self.contentView bounds];
	frame.origin.x += 8;
	frame.origin.y += 4;
	frame.size.width -= 16;
	
	frame.size.height = 22;
	[_title setFrame: frame];
	
	frame.origin.y += 27;
	frame.size.height = 18;
	[_venue setFrame: frame];
	
	frame.origin.y += 22;
	[_location setFrame: frame];
}
-(void)dealloc {
	[_title release];
	[_venue release];
	[_location release];
	[super dealloc];
}
@end

@implementation EventsListViewController
- (void)loadView {
	[super loadView];
	if(_username)
		[self showNowPlayingButton:[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate isPlaying]];
	self.view = _table;
}
- (void)viewDidLoad {
	[super viewDidLoad];
	if(!_username)
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_trackDidChange:) name:kLastFMRadio_TrackDidChange object:nil];
	_lock = [[NSLock alloc] init];
}
- (void)viewWillAppear:(BOOL)animated {
	[_table scrollRectToVisible:[_table frame] animated:NO];
	if(_username)
		[self showNowPlayingButton:[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate isPlaying]];
}
- (void)_trackDidChange:(NSNotification*)notification {
	[NSThread detachNewThreadSelector:@selector(_fetchEvents:) toTarget:self withObject:[notification userInfo]];
}
- (void)_processEvents:(NSArray *)events {
	int i,lasti = 0;
	[_events release];
	[_eventDates release];

	_events = [events retain];
	_eventDates = [[NSMutableArray alloc] init];
	
	if([_events count]) {
		NSString *date, *lastDate = [self formatDate:[[_events objectAtIndex:0] objectForKey:@"startDate"]];
		
		for(i=0; i<[_events count]; i++) {
			NSDictionary *event = [_events objectAtIndex:i];
			date = [self formatDate:[event objectForKey:@"startDate"]];
			if(![lastDate isEqualToString:date]) {
				[_eventDates addObject:[NSDictionary dictionaryWithObjectsAndKeys:lastDate,@"date",[NSNumber numberWithInt:i-lasti],@"count",[NSNumber numberWithInt:lasti],@"index",nil]];
				lasti = i;
				lastDate = date;
			}
		}
		[_eventDates addObject:[NSDictionary dictionaryWithObjectsAndKeys:lastDate,@"date",[NSNumber numberWithInt:i-lasti],@"count",[NSNumber numberWithInt:lasti],@"index",nil]];
		self.tabBarItem.badgeValue = [NSString stringWithFormat:@"%i", [_events count]];
	} else {
		self.tabBarItem.badgeValue = nil;
	}
	[_table reloadData];
	[_table scrollRectToVisible:[_table frame] animated:YES];
}
- (BOOL)isAttendingEvent:(NSString *)event_id {
	for(NSString *event in _attendingEvents) {
		if([event isEqualToString:event_id]) {
			return YES;
		}
	}
	return NO;
}
- (id)initWithUsername:(NSString *)user {
	if(self = [super init]) {
		self.title = [NSString stringWithFormat:@"%@'s Events", user];
		_username = [user retain];
		_table = [[UITableView alloc] initWithFrame:CGRectMake(0,0,320,460)];
		_table.delegate = self;
		_table.dataSource = self;
		NSArray *events = [[LastFMService sharedInstance] eventsForUser:user];
		if([LastFMService sharedInstance].error) {
			[((MobileLastFMApplicationDelegate *)([UIApplication sharedApplication].delegate)) reportError:[LastFMService sharedInstance].error];
			[self release];
			return nil;
		}
		[self _processEvents:events];
		events = [[LastFMService sharedInstance] eventsForUser:[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"]];
		_attendingEvents = [[NSMutableArray alloc] init];
		for(NSDictionary *event in events) {
			[_attendingEvents addObject:[event objectForKey:@"id"]];
		}
	}
	return self;
}
- (void)_fetchEvents:(NSDictionary *)trackInfo {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[_lock lock];
	[_attendingEvents release];
	_attendingEvents = [[NSMutableArray alloc] init];
	NSArray *attendingEvents = [[LastFMService sharedInstance] eventsForUser:[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"]];
	for(NSDictionary *event in attendingEvents) {
		[_attendingEvents addObject:[event objectForKey:@"id"]];
	}
	[self performSelectorOnMainThread:@selector(_processEvents:) withObject:[[LastFMService sharedInstance] eventsForArtist:[trackInfo objectForKey:@"creator"]] waitUntilDone:YES];
	[_lock unlock];
	[pool release];
}
- (NSString *)formatDate:(NSString *)input {
	CFDateFormatterRef inputDateFormatter = CFDateFormatterCreate(NULL, CFLocaleCopyCurrent(), kCFDateFormatterMediumStyle, kCFDateFormatterNoStyle);
	CFDateFormatterSetFormat(inputDateFormatter, (CFStringRef)@"EEE, dd MMM yyyy");
	CFDateRef date = CFDateFormatterCreateDateFromString(kCFAllocatorDefault, inputDateFormatter, (CFStringRef)[NSString stringWithString:input], NULL);
	CFDateFormatterRef outputDateFormatter = CFDateFormatterCreate(NULL, CFLocaleCopyCurrent(), kCFDateFormatterShortStyle, kCFDateFormatterNoStyle);
	
	CFStringRef str = CFDateFormatterCreateStringWithDate(NULL, outputDateFormatter, date);
	NSString *output = [NSString stringWithString:(NSString *)str];
	CFRelease(inputDateFormatter);
	CFRelease(outputDateFormatter);
	CFRelease(str);
	CFRelease(date);
	return output;
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	if([_eventDates count])
		return [_eventDates count];
	else
		return 1;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if([_eventDates count])
		return [[[_eventDates objectAtIndex:section] objectForKey:@"count"] intValue];
	else
		return 1;
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if([_eventDates count])
		return [[_eventDates objectAtIndex:section] objectForKey:@"date"];
	else
		return nil;
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 78;
}
- (void)doneButtonPressed:(id)sender {
	EventDetailViewController *e = (EventDetailViewController *)sender;
	if([e attendance] == eventStatusNotAttending) {
		[_attendingEvents removeObject:[e.event objectForKey:@"id"]];
		if(_username) {
			NSMutableArray *events = [[NSMutableArray alloc] init];
			for(NSDictionary *event in _events) {
				if(![[event objectForKey:@"id"] isEqualToString:[e.event objectForKey:@"id"]])
					[events addObject:event];
			}
			[self _processEvents:events];
			[events release];
		}
	} else {
		[_attendingEvents addObject:[e.event objectForKey:@"id"]];
	}
	[self.navigationController dismissModalViewControllerAnimated:YES];
	if(!_username)
		[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:YES];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)newIndexPath {
	int offset = 0;
	if([_eventDates count]) {
		offset = [[[_eventDates objectAtIndex:[newIndexPath section]] objectForKey:@"index"] intValue];
	}
	EventDetailViewController *e = [[EventDetailViewController alloc] initWithNibName:@"EventDetailsView" bundle:nil];
	e.event = [_events objectAtIndex:offset + [newIndexPath row]];
	e.delegate = self;
	[self.navigationController presentModalViewController:e animated:YES];
	if([self isAttendingEvent:[e.event objectForKey:@"id"]]) {
		[e setAttendance:eventStatusAttending];
	} else {
		[e setAttendance:eventStatusNotAttending];
	}
	[e release];
	[tableView deselectRowAtIndexPath:newIndexPath animated:YES];
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if([_eventDates count]) {
		int offset = [[[_eventDates objectAtIndex:[indexPath section]] objectForKey:@"index"] intValue];
		EventCell *cell = (EventCell *)[tableView dequeueReusableCellWithIdentifier:@"eventcell"];
		if(!cell)
			cell = [[EventCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"eventcell"];
		[cell setEvent:[_events objectAtIndex:offset+[indexPath row]]];
		return cell;
	} else {
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"NoEventsCell"];
		if(!cell) {
			cell = [[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"NoEventsCell"];
			UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0,0,320,70)];
			label.text = NSLocalizedString(@"No upcoming events", @"No events available");
			label.textAlignment = UITextAlignmentCenter;
			[cell.contentView addSubview: label];
			[label release];
		}
		return cell;
	}
}
- (void)dealloc {
	[_events release];
	[_eventDates release];
	[_attendingEvents release];
	[_username release];
	[super dealloc];
}
@end

@implementation EventDetailViewController
@synthesize event, delegate;
-(void)_updateEvent:(NSDictionary *)update {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[[LastFMService sharedInstance] attendEvent:[[update objectForKey:@"id"] intValue] status:[[update objectForKey:@"status"] intValue]];
	if([LastFMService sharedInstance].error) {
		[((MobileLastFMApplicationDelegate *)([UIApplication sharedApplication].delegate)) reportError:[LastFMService sharedInstance].error];
	}
	[pool release];
}
-(void)_fetchImage:(NSString *)url {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSData *imageData;
	if(shouldUseCache(CACHE_FILE([url md5sum]), 1*HOURS)) {
		imageData = [[NSData alloc] initWithContentsOfFile:CACHE_FILE([url md5sum])];
	} else {
		imageData = [[NSData alloc] initWithContentsOfURL:[NSURL URLWithString:url]];
		[imageData writeToFile:CACHE_FILE([url md5sum]) atomically: YES];
	}
	UIImage *image = [[UIImage alloc] initWithData:imageData];
	_image.image = image;
	[image release];
	[imageData release];
	[pool release];
}
- (void)viewDidLoad {
	CFDateFormatterRef inputDateFormatter = CFDateFormatterCreate(NULL, CFLocaleCopyCurrent(), kCFDateFormatterMediumStyle, kCFDateFormatterNoStyle);
	CFDateFormatterSetFormat(inputDateFormatter, (CFStringRef)@"EEE, dd MMM yyyy");
	CFDateRef date = CFDateFormatterCreateDateFromString(kCFAllocatorDefault, inputDateFormatter, (CFStringRef)[event objectForKey:@"startDate"], NULL);
	CFDateFormatterRef outputDateFormatter = CFDateFormatterCreate(NULL, CFLocaleCopyCurrent(), kCFDateFormatterShortStyle, kCFDateFormatterNoStyle);
	
	CFDateFormatterSetFormat(outputDateFormatter, (CFStringRef)@"MMM");
	NSString *month = (NSString *)CFDateFormatterCreateStringWithDate(NULL, outputDateFormatter, date);
	_month.text = month;
	[month release];
	
	CFDateFormatterSetFormat(outputDateFormatter, (CFStringRef)@"d");
	NSString *day = (NSString *)CFDateFormatterCreateStringWithDate(NULL, outputDateFormatter, date);
	_day.text = day;
	[day release];
	
	CFRelease(outputDateFormatter);
	CFRelease(inputDateFormatter);
	CFRelease(date);

	_eventTitle.text = [event objectForKey:@"title"];
	NSMutableString *artists = [[NSMutableString alloc] initWithString:[event objectForKey:@"headliner"]];
	if([[event objectForKey:@"artists"] isKindOfClass:[NSArray class]] && [[event objectForKey:@"artists"] count] > 0) {
		for(NSString *artist in [event objectForKey:@"artists"]) {
			if(![artist isEqualToString:[event objectForKey:@"headliner"]])
				[artists appendFormat:@", %@", artist];
		}
	}
	_artists.text = artists;
	[artists release];
	_venue.text = [event objectForKey:@"venue"];
	NSMutableString *address = [[NSMutableString alloc] init];
	if([[event objectForKey:@"street"] length]) {
		[address appendFormat:@"%@\n", [event objectForKey:@"street"]];
	}
	if([[event objectForKey:@"city"] length]) {
		[address appendFormat:@"%@ ", [event objectForKey:@"city"]];
	}
	if([[event objectForKey:@"postalcode"] length]) {
		[address appendFormat:@"%@", [event objectForKey:@"postalcode"]];
	}
	if([[event objectForKey:@"country"] length]) {
		[address appendFormat:@"\n%@", [event objectForKey:@"country"]];
	}
	_address.text = address;
	[address release];
	[NSThread detachNewThreadSelector:@selector(_fetchImage:) toTarget:self withObject:[event objectForKey:@"image"]];
}
- (int)attendance {
	switch([_attendance selectedRowInComponent:0]) {
		case 0:
			return eventStatusNotAttending;
		case 1:
			return eventStatusMaybeAttending;
		case 2:
			return eventStatusAttending;
	}
}
- (void)setAttendance:(int)status {
	switch(status) {
		case eventStatusNotAttending:
			[_attendance selectRow:0 inComponent:0 animated:YES];
			break;
		case eventStatusMaybeAttending:
			[_attendance selectRow:1 inComponent:0 animated:YES];
			break;
		case eventStatusAttending:
			[_attendance selectRow:2 inComponent:0 animated:YES];
			break;
	}
}
- (IBAction)doneButtonPressed:(id)sender {
	NSNumber *status;
	
	switch([_attendance selectedRowInComponent:0]) {
		case 0:
			status = [NSNumber numberWithInt:eventStatusNotAttending];
			break;
		case 1:
			status = [NSNumber numberWithInt:eventStatusMaybeAttending];
			break;
		case 2:
			status = [NSNumber numberWithInt:eventStatusAttending];
			break;
	}
	[NSThread detachNewThreadSelector:@selector(_updateEvent:)
													 toTarget:self
												 withObject:[NSDictionary dictionaryWithObjectsAndKeys:[event objectForKey:@"id"], @"id", status, @"status", nil]];
	[delegate doneButtonPressed:self];
}
- (IBAction)mapsButtonPressed:(id)sender {
	NSMutableString *query =[[NSMutableString alloc] init];
	if([[event objectForKey:@"street"] length]) {
		[query appendFormat:@"%@,", [event objectForKey:@"street"]];
	}
	if([[event objectForKey:@"city"] length]) {
		[query appendFormat:@" %@,", [event objectForKey:@"city"]];
	}
	if([[event objectForKey:@"postalcode"] length]) {
		[query appendFormat:@" %@", [event objectForKey:@"postalcode"]];
	}
	if([[event objectForKey:@"country"] length]) {
		[query appendFormat:@" %@", [event objectForKey:@"country"]];
	}
	[[UIApplication sharedApplication] openURLWithWarning:[NSURL URLWithString:[NSString stringWithFormat:@"http://maps.google.com/?f=q&q=%@&ie=UTF8&om=1&iwloc=addr", [query URLEscaped]]]];
}
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
	return 1;
}
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
	return 3;
}
- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
	switch(row) {
		case 0:
			return @"Not attending";
		case 1:
			return @"I might attend";
		case 2:
			return @"I will attend";
		default:
			return @"";
	}
}
@end

@implementation PlaybackViewController
- (void)viewDidLoad {
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_trackDidChange:) name:kLastFMRadio_TrackDidChange object:nil];
	self.moreNavigationController.navigationBar.barStyle = UIBarStyleBlackOpaque;
	UIButton *btn = [[UIButton alloc] initWithFrame: CGRectMake(0, 0, 42, 30)];
	[btn setBackgroundImage:[UIImage imageNamed:@"backBtn.png"] forState:UIControlStateNormal];
	btn.adjustsImageWhenHighlighted = YES;
	[btn addTarget:[UIApplication sharedApplication].delegate action:@selector(hidePlaybackView) forControlEvents:UIControlEventTouchUpInside];
	UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithCustomView: btn];
	self.tabBarController.moreNavigationController.topViewController.navigationItem.leftBarButtonItem = item;
	[item release];
	[btn release];
	self.tabBarController.customizableViewControllers = nil;
}
- (void)_trackDidChange:(NSNotification *)notification {
	self.selectedIndex = 0;
	for(UINavigationController *controller in self.tabBarController.viewControllers) {
		if([controller.topViewController respondsToSelector:@selector(enableLoveButton:)])
			[(PlaybackSubview *)(controller.topViewController) enableLoveButton:YES];
		if([controller.topViewController respondsToSelector:@selector(enableBanButton:)])
			[(PlaybackSubview *)(controller.topViewController) enableBanButton:YES];
	}
	if([self.moreNavigationController.topViewController respondsToSelector:@selector(enableLoveButton:)])
		[(PlaybackSubview *)(self.moreNavigationController.topViewController) enableLoveButton:YES];
	if([self.moreNavigationController.topViewController respondsToSelector:@selector(enableBanButton:)])
		[(PlaybackSubview *)(self.moreNavigationController.topViewController) enableBanButton:YES];
	[self.moreNavigationController popToRootViewControllerAnimated:NO];
}
-(void)_love:(NSTimer *)timer {
	[[LastFMService sharedInstance] loveTrack:[[timer userInfo] objectForKey:@"title"] byArtist:[[timer userInfo] objectForKey:@"creator"]];
	if([LastFMService sharedInstance].error) {
		[((MobileLastFMApplicationDelegate *)([UIApplication sharedApplication].delegate)) reportError:[LastFMService sharedInstance].error];
		for(UINavigationController *controller in self.tabBarController.viewControllers)
			if([controller.topViewController respondsToSelector:@selector(enableLoveButton:)])
				[(PlaybackSubview *)(controller.topViewController) enableLoveButton:YES];
		if([self.moreNavigationController.topViewController respondsToSelector:@selector(enableLoveButton:)])
			[(PlaybackSubview *)(self.moreNavigationController.topViewController) enableLoveButton:YES];
	}
}
-(void)_ban:(NSTimer *)timer {
	[[LastFMService sharedInstance] banTrack:[[timer userInfo] objectForKey:@"title"] byArtist:[[timer userInfo] objectForKey:@"creator"]];
	if([LastFMService sharedInstance].error) {
		[((MobileLastFMApplicationDelegate *)([UIApplication sharedApplication].delegate)) reportError:[LastFMService sharedInstance].error];
		for(UINavigationController *controller in self.tabBarController.viewControllers)
			if([controller.topViewController respondsToSelector:@selector(enableLoveButton:)])
				[(PlaybackSubview *)(controller.topViewController) enableBanButton:YES];
		if([self.moreNavigationController.topViewController respondsToSelector:@selector(enableBanButton:)])
			[(PlaybackSubview *)(self.moreNavigationController.topViewController) enableBanButton:YES];
	} else {
		[[LastFMRadio sharedInstance] skip];
	}
}
-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
	if([[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:NSLocalizedString(@"Love", @"Love Track")]) {
		//Hack to make the loading throbber appear before we block
		[NSTimer scheduledTimerWithTimeInterval:0.1
																		 target:self
																	 selector:@selector(_love:)
																	 userInfo:[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate trackInfo]
																		repeats:NO];
		[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate loveButtonPressed];
		for(UINavigationController *controller in self.tabBarController.viewControllers)
			if([controller.topViewController respondsToSelector:@selector(enableLoveButton:)])
				[(PlaybackSubview *)(controller.topViewController) enableLoveButton:NO];
		if([self.moreNavigationController.topViewController respondsToSelector:@selector(enableLoveButton:)])
			[(PlaybackSubview *)(self.moreNavigationController.topViewController) enableLoveButton:NO];
	} else if([[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:NSLocalizedString(@"Ban", @"Ban Track")]) {
		//Hack to make the loading throbber appear before we block
		[NSTimer scheduledTimerWithTimeInterval:0.1
																		 target:self
																	 selector:@selector(_ban:)
																	 userInfo:[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate trackInfo]
																		repeats:NO];
		[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate banButtonPressed];
		for(UINavigationController *controller in self.tabBarController.viewControllers)
			if([controller.topViewController respondsToSelector:@selector(enableLoveButton:)])
				[(PlaybackSubview *)(controller.topViewController) enableBanButton:NO];
		if([self.moreNavigationController.topViewController respondsToSelector:@selector(enableBanButton:)])
			[(PlaybackSubview *)(self.moreNavigationController.topViewController) enableBanButton:NO];
	}
}
-(void)loveButtonPressed:(id)sender {
	if(![(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate hasNetworkConnection]) {
		[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate displayError:NSLocalizedString(@"ERROR_NONETWORK", @"No network available") withTitle:NSLocalizedString(@"ERROR_NONETWORK_TITLE", @"No network available title")];
	} else {
		UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Are you sure you want to mark this song as loved?", @"Love Confirmation")
																														 delegate:self
																										cancelButtonTitle:NSLocalizedString(@"Cancel", @"Cancel")
																							 destructiveButtonTitle:nil
																										otherButtonTitles:NSLocalizedString(@"Love", @"Love Track"), nil];
		actionSheet.actionSheetStyle = UIActionSheetStyleBlackTranslucent;
		[actionSheet showInView:self.view];
		[actionSheet release];
	}
}
-(void)banButtonPressed:(id)sender {
	if(![(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate hasNetworkConnection]) {
		[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate displayError:NSLocalizedString(@"ERROR_NONETWORK", @"No network available") withTitle:NSLocalizedString(@"ERROR_NONETWORK_TITLE", @"No network available title")];
	} else {
		UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Are you sure you want to mark this song as banned?", @"Ban Confirmation")
																														 delegate:self
																										cancelButtonTitle:NSLocalizedString(@"Cancel", @"Cancel")
																							 destructiveButtonTitle:NSLocalizedString(@"Ban", @"Ban Track")
																										otherButtonTitles:nil];
		actionSheet.actionSheetStyle = UIActionSheetStyleBlackTranslucent;
		[actionSheet showInView:self.view];
		[actionSheet release];
	}
}
-(void)skipButtonPressed:(id)sender {
	[((MobileLastFMApplicationDelegate*)([UIApplication sharedApplication].delegate)) skipButtonPressed:sender];
}
-(void)stopButtonPressed:(id)sender {
	[[LastFMRadio sharedInstance] stop];
	[((MobileLastFMApplicationDelegate*)([UIApplication sharedApplication].delegate)) hidePlaybackView];
}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
- (void)dealloc {
	[super dealloc];
}
@end