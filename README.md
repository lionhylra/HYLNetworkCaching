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
                success(data: responseObject)//1
            }) { (operation, error) -> Void in
               failure(error: error)
            }
        }
    }

//[1]:What you put into the success closure will be what you will get from func fetchDataForModelName(modelName:String, success:((data:AnyObject?)->Void)?, failure:((error:NSError)->Void)?)
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

For the first time app requests data, the cache doesn't has the data. So it first fetch data from network API, then return the data immediately on main thread and meanwhile save the data to the cache on anoher thread.

After that, when app requests data, it first get the cached data from Core Data, and then request the API. After receiving the data from API, it returns the data to the success closure immediately and meanwhile update(delete the old data and insert the new data) the cached data in Core Data.

If network is not available, it returns cached data only and the failure closure is called.

![activity diagram](https://github.com/lionhylra/HYLNetworkCaching/blob/master/activity%20diagram.png?raw=true)