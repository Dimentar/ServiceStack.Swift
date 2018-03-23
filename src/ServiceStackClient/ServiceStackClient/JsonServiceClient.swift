//
//  JsonServiceClient.swift
//  ServiceStackClient
//
//  Created by Demis Bellot on 1/29/15.
//  Copyright (c) 2015 ServiceStack LLC. All rights reserved.
//

import Foundation

public protocol IReturn
{
    associatedtype Return : JsonSerializable
}

public protocol IReturnVoid {}

public protocol IGet {}
public protocol IPost {}
public protocol IPut {}
public protocol IDelete {}
public protocol IPatch {}

public protocol ServiceClient
{
    func get<T : IReturn>(_ request:T) throws -> T.Return where T : JsonSerializable
    func get<T : IReturnVoid>(_ request:T) throws -> Void where T : JsonSerializable
    func get<T : IReturn>(_ request:T, query:[String:String]) throws -> T.Return where T : JsonSerializable
    func get<T : JsonSerializable>(_ relativeUrl:String) throws -> T
    func getAsync<T : IReturn>(_ request:T) -> Promise<T.Return> where T : JsonSerializable
    func getAsync<T : IReturnVoid>(_ request:T) -> Promise<Void> where T : JsonSerializable
    func getAsync<T : IReturn>(_ request:T, query:[String:String]) -> Promise<T.Return> where T : JsonSerializable
    func getAsync<T : JsonSerializable>(_ relativeUrl:String) -> Promise<T>
    
    func post<T : IReturn>(_ request:T) throws -> T.Return where T : JsonSerializable
    func post<T : IReturnVoid>(_ request:T) throws -> Void where T : JsonSerializable
    func post<Response : JsonSerializable, Request:JsonSerializable>(_ relativeUrl:String, request:Request?) throws -> Response
    func postAsync<T : IReturn>(_ request:T) -> Promise<T.Return> where T : JsonSerializable
    func postAsync<T : IReturnVoid>(_ request:T) -> Promise<Void> where T : JsonSerializable
    func postAsync<Response : JsonSerializable, Request:JsonSerializable>(_ relativeUrl:String, request:Request?) -> Promise<Response>
    
    func put<T : IReturn>(_ request:T) throws -> T.Return where T : JsonSerializable
    func put<T : IReturnVoid>(_ request:T) throws -> Void where T : JsonSerializable
    func put<Response : JsonSerializable, Request:JsonSerializable>(_ relativeUrl:String, request:Request?) throws -> Response
    func putAsync<T : IReturn>(_ request:T) -> Promise<T.Return> where T : JsonSerializable
    func putAsync<T : IReturnVoid>(_ request:T) -> Promise<Void> where T : JsonSerializable
    func putAsync<Response : JsonSerializable, Request:JsonSerializable>(_ relativeUrl:String, request:Request?) -> Promise<Response>
    
    func delete<T : IReturn>(_ request:T) throws -> T.Return where T : JsonSerializable
    func delete<T : IReturnVoid>(_ request:T) throws -> Void where T : JsonSerializable
    func delete<T : IReturn>(_ request:T, query:[String:String]) throws -> T.Return where T : JsonSerializable
    func delete<T : JsonSerializable>(_ relativeUrl:String) throws -> T
    func deleteAsync<T : IReturn>(_ request:T) -> Promise<T.Return> where T : JsonSerializable
    func deleteAsync<T : IReturnVoid>(_ request:T) -> Promise<Void> where T : JsonSerializable
    func deleteAsync<T : IReturn>(_ request:T, query:[String:String]) -> Promise<T.Return> where T : JsonSerializable
    func deleteAsync<T : JsonSerializable>(_ relativeUrl:String) -> Promise<T>
    
    func patch<T : IReturn>(_ request:T) throws -> T.Return where T : JsonSerializable
    func patch<T : IReturnVoid>(_ request:T) throws -> Void where T : JsonSerializable
    func patch<Response : JsonSerializable, Request:JsonSerializable>(_ relativeUrl:String, request:Request?) throws -> Response
    func patchAsync<T : IReturn>(_ request:T) -> Promise<T.Return> where T : JsonSerializable
    func patchAsync<T : IReturnVoid>(_ request:T) -> Promise<Void> where T : JsonSerializable
    func patchAsync<Response : JsonSerializable, Request:JsonSerializable>(_ relativeUrl:String, request:Request?) -> Promise<Response>
    
    func send<T : IReturn>(_ request:T) throws -> T.Return where T : JsonSerializable
    func send<T : IReturnVoid>(_ request:T) throws -> Void where T : JsonSerializable
    func send<T : JsonSerializable>(intoResponse:T, request:NSMutableURLRequest) throws -> T
    func sendAsync<T : JsonSerializable>(intoResponse:T, request:NSMutableURLRequest) -> Promise<T>
    
    func getData(_ url: String) throws -> Data
    func getData<T: JsonSerializable>(_ dto: T) throws -> Data
    func getDataAsync(_ url: String) -> Promise<Data>
    func getDataAsync<T: JsonSerializable>(_ dto: T) -> Promise<Data>
}

open class JsonServiceClient : ServiceClient
{
    open var baseUrl:String
    open var replyUrl:String
    open var domain:String
    open var lastError:NSError?
    open var lastTask:URLSessionDataTask?
    open var onError:((NSError) -> Void)?
    open var timeout:TimeInterval?
    open var cachePolicy:NSURLRequest.CachePolicy = NSURLRequest.CachePolicy.reloadIgnoringLocalCacheData
    
    open var requestFilter:((NSMutableURLRequest) -> Void)?
    open var responseFilter:((URLResponse) -> Void)?
    
    public struct Global
    {
        static var requestFilter:((NSMutableURLRequest) -> Void)?
        static var responseFilter:((URLResponse) -> Void)?
        static var onError:((NSError) -> Void)?
    }
    
    public init(baseUrl:String)
    {
        self.baseUrl = baseUrl.hasSuffix("/") ? baseUrl : baseUrl + "/"
        self.replyUrl = self.baseUrl + "json/reply/"
        let url = NSURL(string: self.baseUrl)
        self.domain = url!.host!
    }
    
    func createSession() -> URLSession {
        let config = URLSessionConfiguration.default
        
        let session = URLSession(configuration: config)
        return session
    }
    
    func handleError(nsError:NSError) -> NSError {
        return fireErrorCallbacks(error: NSError(domain: domain, code: nsError.code,
                                                 userInfo:["responseStatus": ["errorCode":nsError.code.toString(), "message":nsError.description]]))
    }
    
    func fireErrorCallbacks(error:NSError) -> NSError {
        lastError = error
        if onError != nil {
            onError!(error)
        }
        if Global.onError != nil {
            Global.onError!(error)
        }
        return error
    }
    
    func getItem(map:NSDictionary, key:String) -> Any? {
        return map[String(key[0]).lowercased() + key[1..<key.length]] ?? map[String(key[0]).uppercased() + key[1..<key.length]]
    }
    
    func populateResponseStatusFields(errorInfo:inout [String : Any], withObject:Any) {
        if let status = getItem(map: withObject as! NSDictionary, key: "ResponseStatus") as? NSDictionary {
            if let errorCode = getItem(map: status, key: "errorCode") as? NSString {
                errorInfo["errorCode"] = errorCode
            }
            if let message = getItem(map: status, key: "message") as? NSString {
                errorInfo["message"] = message
            }
            if let stackTrace = getItem(map: status, key: "stackTrace") as? NSString {
                errorInfo["stackTrace"] = stackTrace
            }
            if let errors: Any = getItem(map: status, key: "errors") {
                errorInfo["errors"] = errors
            }
        }
    }
    
    func handleResponse<T : JsonSerializable>(intoResponse:T, data:Data, response:URLResponse, error:NSErrorPointer = nil) -> T? {
        if let nsResponse = response as? HTTPURLResponse {
            if nsResponse.statusCode >= 400 {
                var errorInfo: [String : Any] = [:]
                
                errorInfo["statusCode"] = nsResponse.statusCode
                errorInfo["statusDescription"] = nsResponse.description
                
                if let _ = nsResponse.allHeaderFields["Content-Type"] as? String {
                    if let obj:Any = parseJsonBytes(data) {
                        errorInfo["response"] = obj
                        errorInfo["errorCode"] = nsResponse.statusCode.toString()
                        errorInfo["message"] = nsResponse.statusDescription
                        populateResponseStatusFields(errorInfo: &errorInfo, withObject:obj)
                    }
                }
                
                let ex = fireErrorCallbacks(error: NSError(domain:self.domain, code:nsResponse.statusCode, userInfo:errorInfo))
                if error != nil {
                    error?.pointee = ex
                }
                
                return nil
            }
        }
        
        if (intoResponse is ReturnVoid) {
            return intoResponse
        }
        
        if responseFilter != nil {
            responseFilter!(response)
        }
        if Global.responseFilter != nil {
            Global.responseFilter!(response)
        }
        
        if let json = NSString(data: data, encoding: String.Encoding.utf8.rawValue) {
            if let dto = Type<T>.fromJson(instance: intoResponse, json: json as String) {
                return dto
            }
        }
        return nil
    }
    
    public func createUrl<T : JsonSerializable>(dto:T, query:[String:String] = [:]) -> String {
        var requestUrl = self.replyUrl + T.typeName
        
        var sb = ""
        for pi in T.properties {
            if let strValue = pi.jsonValueAny(instance: dto)?.stripQuotes() {
                sb += sb.length == 0 ? "?" : "&"
                sb += "\(pi.name.urlEncode()!)=\(strValue.urlEncode()!)"
            }
            else if let strValue = pi.stringValueAny(instance: dto) {
                sb += sb.length == 0 ? "?" : "&"
                sb += "\(pi.name.urlEncode()!)=\(strValue.urlEncode()!)"
            }
        }
        
        for (key,value) in query {
            sb += sb.length == 0 ? "?" : "&"
            sb += "\(key)=\(value.urlEncode()!)"
        }
        
        requestUrl += sb
        
        return requestUrl
    }
    
    public func createRequestDto<T : JsonSerializable>(url:String, httpMethod:String, request:T?) -> NSMutableURLRequest {
        var contentType:String?
        var requestBody:Data?
        
        if let dto = request {
            contentType = "application/json"
            requestBody = dto.toJson().data(using: String.Encoding.utf8)
        }
        
        return self.createRequest(url: url, httpMethod: httpMethod, requestType: contentType, requestBody: requestBody)
    }
    
    public func createRequest(url:String, httpMethod:String, requestType:String? = nil, requestBody:Data? = nil) -> NSMutableURLRequest {
        let nsUrl = NSURL(string: url)!
        
        let req = self.timeout == nil
            ? NSMutableURLRequest(url: nsUrl as URL)
            : NSMutableURLRequest(url: nsUrl as URL, cachePolicy: self.cachePolicy, timeoutInterval: self.timeout!)
        
        req.httpMethod = httpMethod
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        
        req.httpBody = requestBody
        if let contentType = requestType {
            req.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        
        if requestFilter != nil {
            requestFilter!(req)
        }
        
        if Global.requestFilter != nil {
            Global.requestFilter!(req)
        }
        
        return req
    }
    
    @discardableResult public func send<T : JsonSerializable>(intoResponse: T, request: NSMutableURLRequest) throws -> T {
        let dataTaskSync = self.createSession().dataTaskSync(request: request as URLRequest)
        self.lastTask = dataTaskSync.task
        
        if dataTaskSync.callback?.response == nil {
            if let error = dataTaskSync.callback?.error {
                throw error
            }
            return T()
        }
        var error: NSError? = NSError(domain: NSURLErrorDomain, code: NSURLErrorUnknown, userInfo: nil)
        if let data = dataTaskSync.callback?.data,
            let response = dataTaskSync.callback?.response,
            let dto = self.handleResponse(intoResponse: intoResponse, data: data, response: response, error: &error) {
            return dto
        }
        if let e = error {
            throw e
        }
        return T()
    }
    
    @discardableResult public func sendAsync<T : JsonSerializable>(intoResponse:T, request:NSMutableURLRequest) -> Promise<T> {
        let pendingPromise = Promise<T>.pending()
        let task = self.createSession().dataTask(with: request as URLRequest) { (data, response, error) in
            if error != nil {
                pendingPromise.resolver.reject(self.handleError(nsError: error! as NSError))
            }
            else {
                var resposneError:NSError?
                let response = self.handleResponse(intoResponse: intoResponse, data: data!, response: response!, error: &resposneError)
                if resposneError != nil {
                    pendingPromise.resolver.reject(self.fireErrorCallbacks(error: resposneError!))
                }
                else if let dto = response {
                    pendingPromise.resolver.fulfill(dto)
                } else {
                    pendingPromise.resolver.fulfill(T()) //return empty dto in promise callbacks
                }
            }
        }
        
        task.resume()
        self.lastTask = task
        return pendingPromise.promise
    }
    
    func resolveUrl(_ relativeOrAbsoluteUrl:String) -> String {
        return relativeOrAbsoluteUrl.hasPrefix("http:")
            || relativeOrAbsoluteUrl.hasPrefix("https:")
            ? relativeOrAbsoluteUrl
            : baseUrl.combinePath(relativeOrAbsoluteUrl)
    }
    
    func hasRequestBody(httpMethod:String) -> Bool
    {
        switch httpMethod {
        case HttpMethods.Get, HttpMethods.Delete, HttpMethods.Head, HttpMethods.Options:
            return false
        default:
            return true
        }
    }
    
    func getSendMethod<T : JsonSerializable>(_ request:T) -> String {
        return request is IGet ?
            HttpMethods.Get
            : request is IPost ?
                HttpMethods.Post
            : request is IPut ?
                HttpMethods.Put
            : request is IDelete ?
                HttpMethods.Delete
            : request is IPatch ?
                HttpMethods.Patch :
            HttpMethods.Post;
    }
    
    public func send<T : IReturn>(_ request:T) throws -> T.Return where T : JsonSerializable {
        let httpMethod = getSendMethod(request)
        if hasRequestBody(httpMethod: httpMethod) {
            return try send(intoResponse: T.Return(), request: self.createRequestDto(url: replyUrl.combinePath(T.typeName), httpMethod:httpMethod, request:request))
        }
        
        return try send(intoResponse: T.Return(), request: self.createRequest(url:self.createUrl(dto: request), httpMethod:httpMethod))
        
    }
    
    public func send<T : IReturnVoid>(_ request:T) throws where T : JsonSerializable {
        let httpMethod = getSendMethod(request)
        if hasRequestBody(httpMethod: httpMethod) {
            try send(intoResponse: ReturnVoid.void, request: self.createRequestDto(url: replyUrl.combinePath(T.typeName), httpMethod:httpMethod, request:request))
        }
        else {
            try send(intoResponse: ReturnVoid.void, request: self.createRequest(url: self.createUrl(dto: request), httpMethod:httpMethod))
        }
    }
    
    public func sendAsync<T : IReturn>(_ request:T) -> Promise<T.Return> where T : JsonSerializable {
        let httpMethod = getSendMethod(request)
        return hasRequestBody(httpMethod: httpMethod)
            ? sendAsync(intoResponse: T.Return(), request: self.createRequestDto(url: replyUrl.combinePath(T.typeName), httpMethod:httpMethod, request:request))
            : sendAsync(intoResponse: T.Return(), request: self.createRequest(url: self.createUrl(dto: request), httpMethod:httpMethod))
    }
    
    public func sendAsync<T : IReturnVoid>(_ request:T) -> Promise<Void> where T : JsonSerializable {
        let httpMethod = getSendMethod(request)
        return hasRequestBody(httpMethod: httpMethod)
            ? sendAsync(intoResponse: ReturnVoid.void, request: self.createRequestDto(url: replyUrl.combinePath(T.typeName), httpMethod:HttpMethods.Post, request:request))
                .asVoid()
            : sendAsync(intoResponse: ReturnVoid.void, request: self.createRequest(url: self.createUrl(dto: request), httpMethod:HttpMethods.Get))
                .asVoid()
    }
    
    
    public func get<T : IReturn>(_ request:T) throws -> T.Return where T : JsonSerializable {
        return try send(intoResponse: T.Return(), request: self.createRequest(url: self.createUrl(dto: request), httpMethod:HttpMethods.Get))
    }
    
    public func get<T : IReturnVoid>(_ request:T) throws -> Void where T : JsonSerializable {
        try send(intoResponse: ReturnVoid.void, request: self.createRequest(url: self.createUrl(dto: request), httpMethod:HttpMethods.Get))
    }
    
    public func get<T : IReturn>(_ request:T, query:[String:String]) throws -> T.Return where T : JsonSerializable {
        return try send(intoResponse: T.Return(), request: self.createRequest(url: self.createUrl(dto: request, query:query), httpMethod:HttpMethods.Get))
    }
    
    public func get<T : JsonSerializable>(_ relativeUrl:String) throws -> T {
        return try send(intoResponse: T(), request: self.createRequest(url: resolveUrl(relativeUrl), httpMethod:HttpMethods.Get))
    }
    
    public func getAsync<T : IReturn>(_ request:T) -> Promise<T.Return> where T : JsonSerializable {
        return sendAsync(intoResponse: T.Return(), request: self.createRequest(url: self.createUrl(dto: request), httpMethod:HttpMethods.Get))
    }
    
    @discardableResult public func getAsync<T : IReturnVoid>(_ request:T) -> Promise<Void> where T : JsonSerializable {
        return sendAsync(intoResponse: ReturnVoid.void, request: self.createRequest(url: self.createUrl(dto: request), httpMethod:HttpMethods.Get))
            .asVoid()
    }
    
    public func getAsync<T : IReturn>(_ request:T, query:[String:String]) -> Promise<T.Return> where T : JsonSerializable {
        return sendAsync(intoResponse: T.Return(), request: self.createRequest(url: self.createUrl(dto: request, query:query), httpMethod:HttpMethods.Get))
    }
    
    public func getAsync<T : JsonSerializable>(_ relativeUrl:String) -> Promise<T> {
        return sendAsync(intoResponse: T(), request: self.createRequest(url: resolveUrl(relativeUrl), httpMethod:HttpMethods.Get))
    }
    
    @discardableResult public func post<T : IReturn>(_ request:T) throws -> T.Return where T : JsonSerializable {
        return try send(intoResponse: T.Return(), request: self.createRequestDto(url: replyUrl.combinePath(T.typeName), httpMethod:HttpMethods.Post, request:request))
    }
    
    public func post<T : IReturnVoid>(_ request:T) throws -> Void where T : JsonSerializable {
        try send(intoResponse: ReturnVoid.void, request: self.createRequestDto(url: replyUrl.combinePath(T.typeName), httpMethod:HttpMethods.Post, request:request))
    }
    
    @discardableResult public func post<Response : JsonSerializable, Request:JsonSerializable>(_ relativeUrl:String, request:Request?) throws -> Response {
        return try send(intoResponse: Response(), request: self.createRequestDto(url: resolveUrl(relativeUrl), httpMethod:HttpMethods.Post, request:request))
    }
    
    @discardableResult public func postAsync<T : IReturn>(_ request:T) -> Promise<T.Return> where T : JsonSerializable {
        return sendAsync(intoResponse: T.Return(), request: self.createRequestDto(url: replyUrl.combinePath(T.typeName), httpMethod:HttpMethods.Post, request:request))
    }
    
    @discardableResult public func postAsync<T : IReturnVoid>(_ request:T) -> Promise<Void> where T : JsonSerializable {
        return sendAsync(intoResponse: ReturnVoid.void, request: self.createRequestDto(url: replyUrl.combinePath(T.typeName), httpMethod:HttpMethods.Post, request:request))
            .asVoid()
    }
    
    @discardableResult public func postAsync<Response : JsonSerializable, Request:JsonSerializable>(_ relativeUrl:String, request:Request?) -> Promise<Response> {
        return sendAsync(intoResponse: Response(), request: self.createRequestDto(url: resolveUrl(relativeUrl), httpMethod:HttpMethods.Post, request:request))
    }
    
    
    @discardableResult public func put<T : IReturn>(_ request:T) throws -> T.Return where T : JsonSerializable {
        return try send(intoResponse: T.Return(), request: self.createRequestDto(url: replyUrl.combinePath(T.typeName), httpMethod:HttpMethods.Put, request:request))
    }
    
    public func put<T : IReturnVoid>(_ request:T) throws -> Void where T : JsonSerializable {
        try send(intoResponse: ReturnVoid.void, request: self.createRequestDto(url: replyUrl.combinePath(T.typeName), httpMethod:HttpMethods.Put, request:request))
    }
    
    @discardableResult public func put<Response : JsonSerializable, Request:JsonSerializable>(_ relativeUrl:String, request:Request?) throws -> Response {
        return try send(intoResponse: Response(), request: self.createRequestDto(url: resolveUrl(relativeUrl), httpMethod:HttpMethods.Put, request:request))
    }
    
    @discardableResult public func putAsync<T : IReturn>(_ request:T) -> Promise<T.Return> where T : JsonSerializable {
        return sendAsync(intoResponse: T.Return(), request: self.createRequestDto(url: replyUrl.combinePath(T.typeName), httpMethod:HttpMethods.Put, request:request))
    }
    
    @discardableResult public func putAsync<T : IReturnVoid>(_ request:T) -> Promise<Void> where T : JsonSerializable {
        return sendAsync(intoResponse: ReturnVoid.void, request: self.createRequestDto(url: replyUrl.combinePath(T.typeName), httpMethod:HttpMethods.Put, request:request))
            .asVoid()
    }
    
    @discardableResult public func putAsync<Response : JsonSerializable, Request:JsonSerializable>(_ relativeUrl:String, request:Request?) -> Promise<Response> {
        return sendAsync(intoResponse: Response(), request: self.createRequestDto(url: resolveUrl(relativeUrl), httpMethod:HttpMethods.Put, request:request))
    }
    
    
    @discardableResult public func delete<T : IReturn>(_ request:T) throws -> T.Return where T : JsonSerializable {
        return try send(intoResponse: T.Return(), request: self.createRequest(url: self.createUrl(dto: request), httpMethod:HttpMethods.Delete))
    }
    
    public func delete<T : IReturnVoid>(_ request:T) throws -> Void where T : JsonSerializable {
        try send(intoResponse: ReturnVoid.void, request: self.createRequest(url: self.createUrl(dto: request), httpMethod:HttpMethods.Delete))
    }
    
    @discardableResult public func delete<T : IReturn>(_ request:T, query:[String:String]) throws -> T.Return where T : JsonSerializable {
        return try send(intoResponse: T.Return(), request: self.createRequest(url: self.createUrl(dto: request, query:query), httpMethod:HttpMethods.Delete))
    }
    
    @discardableResult public func delete<T : JsonSerializable>(_ relativeUrl:String) throws -> T {
        return try send(intoResponse: T(), request: self.createRequest(url: resolveUrl(relativeUrl), httpMethod:HttpMethods.Delete))
    }
    
    @discardableResult public func deleteAsync<T : IReturn>(_ request:T) -> Promise<T.Return> where T : JsonSerializable {
        return sendAsync(intoResponse: T.Return(), request: self.createRequest(url: self.createUrl(dto: request), httpMethod:HttpMethods.Delete))
    }
    
    @discardableResult public func deleteAsync<T : IReturnVoid>(_ request:T) -> Promise<Void> where T : JsonSerializable {
        return sendAsync(intoResponse: ReturnVoid.void, request: self.createRequest(url: self.createUrl(dto: request), httpMethod:HttpMethods.Delete))
            .asVoid()
    }
    
    @discardableResult public func deleteAsync<T : IReturn>(_ request:T, query:[String:String]) -> Promise<T.Return> where T : JsonSerializable {
        return sendAsync(intoResponse: T.Return(), request: self.createRequest(url: self.createUrl(dto: request, query:query), httpMethod:HttpMethods.Delete))
    }
    
    @discardableResult public func deleteAsync<T : JsonSerializable>(_ relativeUrl:String) -> Promise<T> {
        return sendAsync(intoResponse: T(), request: self.createRequest(url: resolveUrl(relativeUrl), httpMethod:HttpMethods.Delete))
    }
    
    
    @discardableResult public func patch<T : IReturn>(_ request:T) throws -> T.Return where T : JsonSerializable {
        return try send(intoResponse: T.Return(), request: self.createRequestDto(url: replyUrl.combinePath(T.typeName), httpMethod:HttpMethods.Patch, request:request))
    }
    
    public func patch<T : IReturnVoid>(_ request:T) throws -> Void where T : JsonSerializable {
        try send(intoResponse: ReturnVoid.void, request: self.createRequestDto(url: replyUrl.combinePath(T.typeName), httpMethod:HttpMethods.Patch, request:request))
    }
    
    @discardableResult public func patch<Response : JsonSerializable, Request:JsonSerializable>(_ relativeUrl:String, request:Request?) throws -> Response {
        return try send(intoResponse: Response(), request: self.createRequestDto(url: resolveUrl(relativeUrl), httpMethod:HttpMethods.Patch, request:request))
    }
    
    @discardableResult public func patchAsync<T : IReturn>(_ request:T) -> Promise<T.Return> where T : JsonSerializable {
        return sendAsync(intoResponse: T.Return(), request: self.createRequestDto(url: replyUrl.combinePath(T.typeName), httpMethod:HttpMethods.Patch, request:request))
    }
    
    @discardableResult public func patchAsync<T : IReturnVoid>(_ request:T) -> Promise<Void> where T : JsonSerializable {
        return sendAsync(intoResponse: ReturnVoid.void, request: self.createRequestDto(url: replyUrl.combinePath(T.typeName), httpMethod:HttpMethods.Patch, request:request))
            .asVoid()
    }
    
    @discardableResult public func patchAsync<Response : JsonSerializable, Request:JsonSerializable>(_ relativeUrl:String, request:Request?) -> Promise<Response> {
        return sendAsync(intoResponse: Response(), request: self.createRequestDto(url: resolveUrl(relativeUrl), httpMethod:HttpMethods.Patch, request:request))
    }
}

extension JsonServiceClient {
    internal func getData(_ urlRequest: URLRequest) throws -> Data {
        let dataTaskSync = self.createSession().dataTaskSync(request: urlRequest as URLRequest)
        self.lastTask = dataTaskSync.task
        
        if let data = dataTaskSync.callback?.data {
            return data
        }
        
        if let error = dataTaskSync.callback?.error {
            throw error
        }
        
        return Data()
    }
    
    public func getData(_ url: String) throws -> Data {
        let urlRequest = createRequest(url: resolveUrl(url), httpMethod: HttpMethods.Get)
        return try getData(urlRequest as URLRequest)
    }
    
    public func getData<T : JsonSerializable>(_ dto: T) throws -> Data {
        let urlRequest = createRequest(url: createUrl(dto: dto), httpMethod: HttpMethods.Get)
        return try getData(urlRequest as URLRequest)
    }
    
    internal func getDataAsync(_ urlRequest: URLRequest) -> Promise<Data> {
        let pendingPromise = Promise<Data>.pending()
        
        let task = self.createSession().dataTask(with: urlRequest as URLRequest) { (data, response, error) in
            if let error = error {
                pendingPromise.resolver.reject(self.handleError(nsError: error as NSError))
                return
            }
            
            if let data = data {
                pendingPromise.resolver.fulfill(data)
                return
            }
            
            pendingPromise.resolver.fulfill(Data())
        }
        
        task.resume()
        self.lastTask = task
        
        return pendingPromise.promise
    }
    
    public func getDataAsync(_ url: String) -> Promise<Data> {
        let urlRequest = createRequest(url: resolveUrl(url), httpMethod: HttpMethods.Get)
        return getDataAsync(urlRequest as URLRequest)
    }
    
    public func getDataAsync<T : JsonSerializable>(_ dto: T) -> Promise<Data> {
        let urlRequest = createRequest(url: createUrl(dto: dto), httpMethod: HttpMethods.Get)
        return getDataAsync(urlRequest as URLRequest)
    }
}

extension URLSession {
    public typealias URLSessionDataCallback = (data: Data?, response: URLResponse?, error: Error?)
    public typealias URLSessionDataTaskSync = (task: URLSessionDataTask, callback: URLSessionDataCallback?)
    
    public func dataTaskSync(request: URLRequest) -> URLSessionDataTaskSync {
        var callback: URLSessionDataCallback?
        let ds = DispatchSemaphore(value: 0)
        let task = self.dataTask(with: request as URLRequest) { data, response, error in
            callback = (data: data, response: response, error: error)
            ds.signal()
        }
        
        task.resume()
        ds.wait()
        return (task: task, callback: callback)
    }
}

extension HTTPURLResponse {
    
    //Unfortunately no API gives us the real statusDescription so using Status Code descriptions instead
    public var statusDescription:String {
        switch self.statusCode {
        case 200: return "OK"
        case 201: return "Created"
        case 202: return "Accepted"
        case 205: return "No Content"
        case 206: return "Partial Content"
            
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 403: return "Forbidden"
        case 404: return "Not Found"
        case 405: return "Method Not Allowed"
        case 406: return "Not Acceptable"
        case 407: return "Proxy Authentication Required"
        case 408: return "Request Timeout"
        case 409: return "Conflict"
        case 410: return "Gone"
        case 418: return "I'm a teapot"
            
        case 500: return "Internal Server Error"
        case 501: return "Not Implemented"
        case 502: return "Bad Gateway"
        case 503: return "Service Unavailable"
            
        default: return "\(self.statusCode)"
        }
    }
}

public struct HttpMethods
{
    static let Get = "GET"
    static let Post = "POST"
    static let Put = "PUT"
    static let Delete = "DELETE"
    static let Head = "HEAD"
    static let Options = "OPTIONS"
    static let Patch = "PATCH"
}
