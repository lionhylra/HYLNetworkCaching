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
let kRawDataAttributeName = "rawData"
let kModelNameAttributeName = "modelName"
//let kIndexAttributeName = "id"
//let kSortKeyAttributName = "sortKey"

protocol HYLNetworkCachingDelegate{
    func fetchDataFromNetworkForModelName(modelName:String,success:((data:AnyObject)->Void)?,failure:((error:NSError)->Void)?)
}

class HYLNetworkCaching: NSObject {
    
    var delegate:HYLNetworkCachingDelegate!
    
    init(delegate:HYLNetworkCachingDelegate){
        self.delegate = delegate
        super.init()
        self.mainManagedObjectContext!.parentContext = self.privateManagedObjectContext!
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "privateManagedObjectContextDidSave:", name: NSManagedObjectContextDidSaveNotification, object: self.privateManagedObjectContext!)
    }
    
    
    // MARK: - internal methods
    func fetchDataForModelName(modelName:String, success:((data:AnyObject?)->Void), failure:((error:NSError)->Void)){
        /* fetch cached data */
        if let cachedData: AnyObject? = fetchDataFromCoredataForModelName(modelName) {
            success(data: cachedData)
        }
            
        if self.delegate == nil {
            return
        }
        
        self.delegate.fetchDataFromNetworkForModelName(modelName, success: { (data) -> Void in
            self.updateCacheForModelName(modelName, data: data)
            success(data: data)
            }, failure: failure)
    }
    
    // MARK: - private methods
    private func updateCacheForModelName(modelName:String, data:AnyObject){
        let context = self.privateManagedObjectContext!
        context.performBlock { () -> Void in
            /* delete all records for that model */
            let request = NSFetchRequest()
            request.entity = NSEntityDescription.entityForName(kEntityName, inManagedObjectContext: context)
            let predicate = NSPredicate(format: "%K == %@", kModelNameAttributeName, modelName)
            request.predicate = predicate
            var error:NSError?
            if let results = context.executeFetchRequest(request, error: &error) {
                for item in results {
                    context.deleteObject(item as! NSManagedObject)
                }
            }
            
            /* create a new entity instance */
            let managedObject = NSEntityDescription.insertNewObjectForEntityForName(kEntityName, inManagedObjectContext: context) as! NSManagedObject
            managedObject.setValue(data, forKey: kRawDataAttributeName)
            managedObject.setValue(modelName, forKey: kModelNameAttributeName)
            
            /* save */
            var saveError:NSError?
            if context.hasChanges && !context.save(&saveError) {
                println("Save private context failed with error: \(saveError!.localizedDescription)")
            }
        }
    }
    
    private func fetchDataFromCoredataForModelName(modelName:String)->AnyObject?{
        let context = self.mainManagedObjectContext!
        let fetchRequest = NSFetchRequest()
        let entity = NSEntityDescription.entityForName(kEntityName, inManagedObjectContext: context)
        fetchRequest.entity = entity
        let predicate = NSPredicate(format: "%K == %@", kModelNameAttributeName, modelName)
        fetchRequest.predicate = predicate
        
        var error:NSError? = nil
        if let results = context.executeFetchRequest(fetchRequest, error: &error){
            if !results.isEmpty {
                return results[0].valueForKey(kRawDataAttributeName)!
            }
        }else if error != nil {
            println("Fetch data from CoreData failed with error:\(error!.localizedDescription)")
            return nil
        }
        return nil
    }
    
    // MARK: - Core Data stack
    
    lazy private var applicationCachesDirectory: NSURL = {
        // The directory the application uses to store the Core Data store file. This code uses a directory named "com.lionhylra.CoreData" in the application's documents Application Support directory.
        let urls = NSFileManager.defaultManager().URLsForDirectory(.CachesDirectory, inDomains: .UserDomainMask)
        return urls[urls.count-1] as! NSURL
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
        var error: NSError? = nil
        var failureReason = "There was an error creating or loading the application's saved data."
        if coordinator!.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: url, options: nil, error: &error) == nil {
            coordinator = nil
            // Report any error we got.
            var dict = [String: AnyObject]()
            dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data"
            dict[NSLocalizedFailureReasonErrorKey] = failureReason
            dict[NSUnderlyingErrorKey] = error
            error = NSError(domain: "YOUR_ERROR_DOMAIN", code: 9999, userInfo: dict)
            // Replace this with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog("Unresolved error \(error), \(error!.userInfo)")
            abort()
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
        if let moc = self.privateManagedObjectContext {
            var error: NSError? = nil
            if moc.hasChanges && !moc.save(&error) {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                NSLog("Unresolved error \(error), \(error!.userInfo)")
                abort()
            }
        }
    }

    func privateManagedObjectContextDidSave(notification:NSNotification) {
        self.mainManagedObjectContext!.performBlock { () -> Void in
            self.mainManagedObjectContext!.mergeChangesFromContextDidSaveNotification(notification)
        }
    }
    
}
