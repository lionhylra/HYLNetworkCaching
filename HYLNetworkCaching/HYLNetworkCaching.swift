//
//  HYLNetworkCaching.swift
//  OfflineCaching
//
//  Created by HeYilei on 10/09/2015.
//  Copyright (c) 2015 HeYilei. All rights reserved.
//

import UIKit
import CoreData

let kManagedObjectModelName = "CachedData"
let kEntityName = "CachedData"
/* Attributes */
let kRawDataAttributeName = "rawData"
let kModelNameAttributeName = "modelName"
//let kFilterKey1AttributeName = "filterKey1"
//let kFilterKey1DefaultValue = "NA"
//let kSortKeyAttributName = "sortKey"

@objc public enum HYLNetworkCachePolicy : Int{
    case DefaultCachePolicy, ReturnCacheDataDontLoad, ReturnCacheDataElseLoad, LoadWithoutCacheData
}

@objc public protocol HYLNetworkCachingDelegate:class {
    func fetchDataFromNetwork(URL url:String,parameters:Dictionary<String, String>?, successHandler:((data:AnyObject)->Void), failureHandler:((error:NSError)->Void))
}

@objc public class HYLNetworkCaching: NSObject {
    
    weak var delegate:HYLNetworkCachingDelegate?
    
    public init(delegate:HYLNetworkCachingDelegate){
        self.delegate = delegate
        super.init()
        self.mainManagedObjectContext!.parentContext = self.privateManagedObjectContext!
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "privateManagedObjectContextDidSave:", name: NSManagedObjectContextDidSaveNotification, object: self.privateManagedObjectContext!)
    }
    
    
    // MARK: - public methods
    // MARK: -
    // MARK: fetchData methods
    public func fetchData(URL url:String, parameters:Dictionary<String, String>?, cachePolicy:HYLNetworkCachePolicy, successHandler:((data:AnyObject?, isCacheData:Bool)->Void)?, failureHandler:((error:NSError)->Void)?){
        /* build url with query */
        let urlWithQuery:String = parameters != nil ? URLWithQuery(originalURL: url, withQueryDictionary: parameters!) : url
        
        /* load cached data according to policy */
        if let cachedData = fetchCachedData(itemIdentifier: urlWithQuery), successHandler = successHandler where cachePolicy != .LoadWithoutCacheData {
            successHandler(data: cachedData, isCacheData: true)
            if cachePolicy == .ReturnCacheDataElseLoad {
                return
            }
        }
        
        if cachePolicy == .ReturnCacheDataDontLoad {
            return
        }
        
        guard let delegate = self.delegate else { return }
        
        delegate.fetchDataFromNetwork(URL: url,parameters: parameters, successHandler: { (data) -> Void in
            successHandler?(data: data, isCacheData:false)
            self.updateCache(itemIdentifier: urlWithQuery, data: data)
        }, failureHandler: { (error) -> Void in
            failureHandler?(error: error)
        })
        
    }
    
    // MARK: clearCache
    public func clearCache(){
        let context = self.privateManagedObjectContext!
        context.performBlock { () -> Void in
            /* delete all records for that model */
            let request = NSFetchRequest()
            request.entity = NSEntityDescription.entityForName(kEntityName, inManagedObjectContext: context)
            do {
                let results = try context.executeFetchRequest(request)
                for item in results {
                    context.deleteObject(item as! NSManagedObject)
                }
            } catch let error as NSError {
                print("FetchRequest failed with error: \(error.localizedDescription)")
            } catch {
                fatalError()
            }
            
            /* save change */
            if context.hasChanges {
                do {
                    try context.save()
                } catch let error as NSError {
                    print("Save private context failed with error: \(error.localizedDescription)")
                } catch {
                    fatalError()
                }
            }
        }
    }
    
    // MARK: - private methods
    
    private func updateCache(itemIdentifier identifier:String, data:AnyObject){
        let context = self.privateManagedObjectContext!
        context.performBlock { () -> Void in
            /* delete all records for that model */
            let request = NSFetchRequest()
            request.entity = NSEntityDescription.entityForName(kEntityName, inManagedObjectContext: context)
            let predicate = NSPredicate(format: "%K == %@", kModelNameAttributeName, identifier)
            request.predicate = predicate
            do {
                let results = try context.executeFetchRequest(request)
                for item in results {
                    context.deleteObject(item as! NSManagedObject)
                }
            } catch let error as NSError {
                print("FetchRequest failed with error: \(error.localizedDescription)")
            } catch {
                fatalError()
            }
            
            /* create a new entity instance */
            let managedObject = NSEntityDescription.insertNewObjectForEntityForName(kEntityName, inManagedObjectContext: context)
            managedObject.setValue(data, forKey: kRawDataAttributeName)
            managedObject.setValue(identifier, forKey: kModelNameAttributeName)
            /* save */
            if context.hasChanges {
                do {
                    try context.save()
                } catch let error as NSError {
                    print("Save private context failed with error: \(error.localizedDescription)")
                } catch {
                    fatalError()
                }
            }
        }

    }
    
    private func fetchCachedData(itemIdentifier identifier:String)->AnyObject?{
        let context = self.mainManagedObjectContext!
        let fetchRequest = NSFetchRequest()
        let entity = NSEntityDescription.entityForName(kEntityName, inManagedObjectContext: context)
        fetchRequest.entity = entity
        let predicate = NSPredicate(format: "%K == %@", kModelNameAttributeName, identifier)
        fetchRequest.predicate = predicate
        
        do {
            let results = try context.executeFetchRequest(fetchRequest)
            if !results.isEmpty {
                return results[0].valueForKey(kRawDataAttributeName)!
            }
        } catch let error as NSError {
            print("Fetch data from CoreData failed with error:\(error.localizedDescription)")
            return nil
        }
        return nil
    }
    
    private func URLWithQuery(originalURL url:String, withQueryDictionary parameters:Dictionary<String, String>)->String{
        if let components = NSURLComponents(string: url) {
            components.queryItems = [NSURLQueryItem]()
            for (key, value) in parameters{
                components.queryItems?.append(NSURLQueryItem(name: key, value: value))
            }
            return components.string!
        }
        return url
    }
    // MARK: - Core Data stack
    
    lazy private var applicationCachesDirectory: NSURL = {
        // The directory the application uses to store the Core Data store file. This code uses a directory named "com.lionhylra.CoreData" in the application's documents Application Support directory.
        let urls = NSFileManager.defaultManager().URLsForDirectory(.CachesDirectory, inDomains: .UserDomainMask)
        return urls[urls.count-1] 
        }()
    
    lazy private var managedObjectModel: NSManagedObjectModel = {
        // The managed object model for the application. This property is not optional. It is a fatal error for the application not to be able to find and load its model.
        let modelURL = NSBundle.mainBundle().URLForResource(kManagedObjectModelName, withExtension: "momd")!
        return NSManagedObjectModel(contentsOfURL: modelURL)!
        }()
    
    lazy private var persistentStoreCoordinator: NSPersistentStoreCoordinator? = {
        // The persistent store coordinator for the application. This implementation creates and return a coordinator, having added the store for the application to it. This property is optional since there are legitimate error conditions that could cause the creation of the store to fail.
        // Create the coordinator and store
        var coordinator: NSPersistentStoreCoordinator? = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        let url = self.applicationCachesDirectory.URLByAppendingPathComponent("HYLNetworkCaching.sqlite")
        var failureReason = "There was an error creating or loading the application's saved data."
        do {
            let options = [NSMigratePersistentStoresAutomaticallyOption:true,NSInferMappingModelAutomaticallyOption:true]
            try coordinator!.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: url, options: options)
        } catch var error as NSError {
            coordinator = nil
            // Report any error we got.
            var dict = [String: AnyObject]()
            dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data"
            dict[NSLocalizedFailureReasonErrorKey] = failureReason
            dict[NSUnderlyingErrorKey] = error
            error = NSError(domain: "YOUR_ERROR_DOMAIN", code: 9999, userInfo: dict)
            // Replace this with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog("Unresolved error \(error), \(error.userInfo)")
            abort()
        } catch {
            fatalError()
        }
        
        return coordinator
        }()
    
    lazy private var privateManagedObjectContext: NSManagedObjectContext? = {
        // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.) This property is optional since there are legitimate error conditions that could cause the creation of the context to fail.
        let coordinator = self.persistentStoreCoordinator
        if coordinator == nil {
            return nil
        }
        var managedObjectContext = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.PrivateQueueConcurrencyType)
            managedObjectContext.persistentStoreCoordinator = coordinator
        return managedObjectContext
        }()
    
    lazy private var mainManagedObjectContext: NSManagedObjectContext? = {
        let coordinator = self.persistentStoreCoordinator
        if coordinator == nil {
            return nil
        }
        var managedObjectContext = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.MainQueueConcurrencyType)
        return managedObjectContext
    }()
    // MARK: - Core Data Saving support
    
    private func saveContext () {
        guard let context = self.privateManagedObjectContext where context.hasChanges else { return }
        
        do {
            try context.save()
        } catch let error as NSError {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog("Unresolved error \(error), \(error.userInfo)")
            abort()
        }
    }

    @objc private func privateManagedObjectContextDidSave(notification:NSNotification) {
        self.mainManagedObjectContext!.performBlock { () -> Void in
            self.mainManagedObjectContext!.mergeChangesFromContextDidSaveNotification(notification)
        }
    }
    
}
