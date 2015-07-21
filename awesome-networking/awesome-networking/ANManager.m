//
//  ANManager.m
//  awesome-networking
//
//  Created by chen Yuheng on 15/7/21.
//  Copyright (c) 2015年 chen Yuheng. All rights reserved.
//

#import "ANManager.h"

@implementation ANManager

+ (ANManager *) sharedInstance
{
    static dispatch_once_t  onceToken;
    static ANManager * sharedInstance;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[ANManager alloc] init];
        sharedInstance.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"text/html",@"text/json", @"text/plain",@"text/xml",@"application/rss+xml", @"application/json", nil];
        sharedInstance.requestSerializer = [AFHTTPRequestSerializer serializer];
        sharedInstance.requestSerializer.timeoutInterval=10.0f;
        sharedInstance.operationQueue = [ANOperationQueue sharedInstance];
        [AFNetworkActivityIndicatorManager sharedManager].enabled=YES;
        sharedInstance.requestSerializer.HTTPMethodsEncodingParametersInURI = [NSSet setWithObjects:@"GET", @"HEAD",nil];
        sharedInstance.requestSerializer.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        [sharedInstance.reachabilityManager startMonitoring];
    });
    return sharedInstance;
}

/**
 *  恢复指定分类下的缓存请求
 *
 *  @param categories 指定分类的集合
 */
- (void)resumeCachedRequestWithCategory:(NSArray *)categories
{
    NSMutableArray *dataArray = [[ANManager sharedInstance] getNeedResendRequests:categories];
    
    for (ANRequest *request  in dataArray) {
            AFHTTPRequestOperation *operation = request.operation;
            [operation start];
            [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
                NSLog(@"requestId is  %ld",request.operationId);
                [[ANManager sharedInstance] removeRequestFromCache:request];
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            }];
    }
}

/**
 *  缓存指定请求到指定分类下
 *
 *  @param request  请求
 *  @param category 分类
 *
 *  @return 请求的唯一标识
 */
- (NSInteger) cacheRequest:(ANRequest *) request category:(int) category
{
    //先读取原来的请求
    NSString *requestCategory = [NSString stringWithFormat:@"%@",@(category)];
    NSUserDefaults *userPrefs = [NSUserDefaults standardUserDefaults];
    NSDictionary *requests = [userPrefs objectForKey:RequestsKey];
    NSMutableDictionary *newRequests = [[NSMutableDictionary alloc]init];
    
    if(![requests isKindOfClass:[NSArray class]])
    {
        newRequests = [NSMutableDictionary dictionaryWithDictionary:requests];
    }
    
    //拿到当前分类下的请求
    
    NSArray *requestValues = [NSArray array];
    if(![requests isKindOfClass:[NSArray class]])
    {
        requestValues = [requests objectForKey:requestCategory];
    }
    
    if(requestValues == nil)
    {
        requestValues = [NSArray array];
    }
    
    NSMutableArray *newRequestValues = [NSMutableArray arrayWithArray:requestValues];
    request.operationId = newRequestValues.count + 1;
    NSData *requestData = [NSKeyedArchiver archivedDataWithRootObject:request];
    NSDictionary *tmp_data = [NSDictionary dictionaryWithObjects:@[requestData,[NSNumber numberWithInteger:request.operationId]] forKeys:@[@"data",@"id"]];
    
    [newRequestValues addObject:tmp_data];
    
    //更新
    [newRequests setObject:newRequestValues forKey:requestCategory];
    [userPrefs setObject:newRequests forKey:RequestsKey];
    [userPrefs synchronize];
    
    return request.operationId;
}

/**
 *  删除缓存的请求
 *
 *  @param request
 */
- (void) removeRequestFromCache:(ANRequest *)request
{
    
    NSString *requestCategory = [NSString stringWithFormat:@"%ld",request.category];
    NSUserDefaults *userPrefs = [NSUserDefaults standardUserDefaults];
    NSDictionary *tmp_newRequests = [userPrefs objectForKey:RequestsKey];
    NSMutableDictionary *newRequests = [NSMutableDictionary dictionary];
    
    if(![tmp_newRequests isKindOfClass:[NSArray class]])
    {
        newRequests = [NSMutableDictionary dictionaryWithDictionary:[userPrefs objectForKey:RequestsKey]];
    }
    
    NSArray *requestValues = [newRequests objectForKey:requestCategory];
    
    NSMutableArray *newRequestValues = [NSMutableArray array];
    
    for (NSDictionary *requestValue in requestValues) {
        ANRequest *tmp = [NSKeyedUnarchiver unarchiveObjectWithData:[requestValue objectForKey:@"data"]];
        if (request.operationId != tmp.operationId) {
            [newRequestValues addObject:requestValue];
        }
    }
    //更新
    [newRequests setObject:newRequestValues forKey:requestCategory];
    [userPrefs setObject:newRequests forKey:RequestsKey];
    [userPrefs synchronize];
}

/**
 *  删除缓存的请求
 *
 *  @param request
 */
- (void) removeRequestFromCacheById:(NSInteger)deleteRequestId
{
    NSArray *categories = @[@"1",@"2",@"3",@"4",@"5"];
    NSUserDefaults *userPrefs = [NSUserDefaults standardUserDefaults];
    NSDictionary *tmp_newRequests = [userPrefs objectForKey:RequestsKey];
    NSMutableDictionary *newRequests = [NSMutableDictionary dictionary];
    
    if(![tmp_newRequests isKindOfClass:[NSArray class]])
    {
        newRequests = [NSMutableDictionary dictionaryWithDictionary:[userPrefs objectForKey:RequestsKey]];
    }
    
    for(NSString *tmp_category_name in categories)
    {
        NSArray *requestValues = [newRequests objectForKey:tmp_category_name];
        
        NSMutableArray *newRequestValues = [NSMutableArray array];
        
        for (NSDictionary *requestValue in requestValues) {
            ANRequest *tmp = [NSKeyedUnarchiver unarchiveObjectWithData:[requestValue objectForKey:@"data"]];
            if (deleteRequestId != tmp.operationId) {
                [newRequestValues addObject:requestValue];
            }
        }
        //更新
        [newRequests setObject:newRequestValues forKey:tmp_category_name];
    }
    
    [userPrefs setObject:newRequests forKey:RequestsKey];
    [userPrefs synchronize];
}

/**
 *  获取指定的分类的请求列表
 *
 */
- (NSMutableArray *) getNeedResendRequests:(NSArray *) categories
{
    if (!categories) {
        categories = @[@"1",@"2",@"3",@"4",@"5"];
    }
    
    NSMutableArray *resendRequests = [NSMutableArray array];
    NSUserDefaults *userPrefs = [NSUserDefaults standardUserDefaults];
    NSDictionary *requests = [userPrefs objectForKey:RequestsKey];
    
    if(!requests)
    {
        return resendRequests;
    }
    
    if(requests.count == 0)
    {
        return resendRequests;
    }
    
    NSMutableArray *requestValues = [NSMutableArray array];
    
    for(NSString *tmp_category_name in categories)
    {
        NSArray *tmp_requests_per_category = [requests objectForKey:tmp_category_name];
        if(tmp_requests_per_category)
            [requestValues addObjectsFromArray:tmp_requests_per_category];
    }
    
    for(NSDictionary *tmp_request_dictionary in requestValues)
    {
        if([tmp_request_dictionary objectForKey:@"data"])
            [resendRequests addObject:[NSKeyedUnarchiver unarchiveObjectWithData:[tmp_request_dictionary objectForKey:@"data"]]];
    }
    
    return resendRequests;
}

- ()
@end
