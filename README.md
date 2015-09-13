# HYLNetworkCaching
A light tool that used to cache network request for offline access.

## Install
Drag and Drop "HYLNetworkCaching" folder into your project.

## How to use
1. Initialize a instance of HYLNetworkCaching

```swift
	// In the network module
	let networkCache = HYLNetworkCaching(delegate: self)
```

2. Implement the method in delegate. In this is the method where you get the data from network and put the data into callback closure. Specify a name for each piece of result returned from network request. We use AFNetworking in the example below.

```swift
	func fetchDataFromNetworkForModelName(modelName: String, success: ((data: AnyObject) -> Void), failure: ((error: NSError) -> Void)) {
        if modelName == "employer" {
            let manager = AFHTTPRequestOperationManager()
            let url = "http://xxx.com/api/getdata"
            manager.GET(url, parameters: nil, success: { (operation, responseObject) -> Void in
                success(data: responseObject)//What you put into the success closure will be what you will get from func fetchDataForModelName(modelName:String, success:((data:AnyObject?)->Void)?, failure:((error:NSError)->Void)?)
            }) { (operation, error) -> Void in
               failure(error: error)
            }
        }
    }
```

3. Then from your view controller, fetch the data.

```swift
let networkCache = ...
networkCache.fetchDataForModelName("TestResult", success: { (data) -> Void in
            if data == nil {
                return
            }
            println("\(data)")
        }) { (error) -> Void in
            println(error.localizedDescription)
        }
```

## What happens behind the scene