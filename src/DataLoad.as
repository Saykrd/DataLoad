package 
{
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.DisplayObject;
	import flash.display.DisplayObjectContainer;
	import flash.display.Loader;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.media.Sound;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.utils.Dictionary;
	
	/**
	 * Loader class for managing asset storage
	 */
	public class DataLoad
	{
		//TODO: Make this class not static :/
		//TODO: Make JSON Compatible
		private static var _assetList:Dictionary;
		private static var _assetBank:Dictionary;
		
		
		/**
		 * Initial startup call
		 * @param	assetListURL - URL of the xml manifest containing all assets that can be loaded
		 * @param	callback - onComplete callback. Executes when the manifest xml has succesfully loaded
		 */
		public static function startup(assetListURL:String = null, callback:Function = null):void {
			trace("[DataLoad] is starting up...");
			
			_assetBank = new Dictionary;
			_assetList = new Dictionary;
			
			if (assetListURL != null) {
				loadAssetsXML(assetListURL, callback);
			}
			
		}
		
		/**
		 * Returns an AssetInfo object containing metadata of the asset listed in the manifest
		 * @param	id
		 * @return
		 */
		private static function getAssetInfoByID(id:String):AssetInfo{
			return _assetList[id];
		}
		
		/**
		 * Returns a list of assetInfo by specific asset type
		 * @param	type - type of asset (display object or text?) Constants set in LoaderInfo
		 * @return
		 */
		private static function getAssetInfoByType(type:String):Vector.<AssetInfo>{
			var assets:Vector.<AssetInfo> = new Vector.<AssetInfo>;
			var asset:AssetInfo;
			
			for each(asset in _assetList){
				if(asset.type == type){
					assets.push(asset);
				}
			}
			
			return assets;
		}
		
		/**
		 * Returns an assetInfo list requested in the given XML
		 * @param	xml
		 * @return
		 */
		private static function getAssetsFromXML(xml:XML):Vector.<AssetInfo>{
			var xmlList:XMLList = xml..@assetID;
			var assets:Vector.<AssetInfo> = new Vector.<AssetInfo>;
			var asset:XML;
			
			for each(asset in xmlList){
				if(!_assetList[String(asset)]) throw new Error("[DataLoadError] This asset is not defined in the assets XML: " + String(asset));
				assets.push(_assetList[String(asset)]);	
			}
			
			return assets;
		}
		
		/**
		 * Loads the manifest XML containing all assetInfo
		 * @param	url
		 * @param	callback
		 */
		public static function loadAssetsXML(url:String, callback:Function = null):void{
			var asset:AssetInfo;
			var list:XML;
			var xml:XML;
			var extension:String;
			var type:String;
			
			var urlLoader:URLLoader = new URLLoader;
			var urlRequest:URLRequest = new URLRequest(url);
			
			trace("[DataLoad] Loading up assets XML from: " + url);
			urlLoader.addEventListener(Event.COMPLETE, loaded);
			urlLoader.load(urlRequest);
			
			function loaded(e:Event):void{
				trace("[DataLoad] Assets XML succesfully loaded from: " + url);
				
				var assetsXML:XML = XML(e.currentTarget.data);
				_assetList = new Dictionary;
				_assetBank = new Dictionary;
				
				for each(list in assetsXML.assetList){
					extension = String(list.@extension);
					type	  = String(list.@type);
					
					for each(xml in list.asset){
						asset = new AssetInfo;
						asset.loadXML(xml, type, extension);
						
						_assetList[asset.id] = asset;
					}
				}
				
				urlLoader.removeEventListener(Event.COMPLETE, loaded);
				urlLoader = null;
				trace("[DataLoad] Startup completed succesfully.");
				if(callback != null)callback();
			}
		}
		
		/**
		 * Loads an asset.
		 * @param	assetID - Assets id as listed in manifest
		 * @param	onComplete - Successful load callback
		 * @param	onProgress - Progress tracking
		 * @param	onError    - Error handler
		 * @return LoadObject - Tracker object that reflects the status of the load
		 */
		public static function loadAssetByID(assetID:String, onComplete:Function  = null, onProgress:Function = null, onError:Function = null):LoadObject{
			if(!_assetList[assetID]) throw new Error("[DataLoadError] This asset is not defined: " + assetID);
			var loadObj:LoadObject = new LoadObject(onComplete, onProgress, onError);
			var asset:AssetInfo = _assetList[assetID];
			loadObj.setNumItems(1);
			load(asset, loadObj);
			return loadObj;
		}
		
		
		/**
		 * Loads multiple assets sequentially.
		 * @param	assets - List of all assetInfo to load
		 * @param	onComplete
		 * @param	onProgress
		 * @param	onError
		 * @return LoadObject - Tracker object that reflects the status of the load
		 */
		public static function loadAssets(assets:Vector.<AssetInfo>, onComplete:Function = null, onProgress:Function = null, onError:Function = null):LoadObject{
			// TODO: Make "assets" ID based.
			var iter:int = 0;
			var loadObj:LoadObject = new LoadObject(checkNextAsset, onProgress, onError);
			trace("[DataLoad] Starting batch load of " + assets.length + " items...");
			loadObj.setNumItems(assets.length);
			load(assets[iter],loadObj);
			
			return loadObj;
			
			function checkNextAsset(obj:LoadObject):void{
				iter++;
				if(iter < assets.length){
					load(assets[iter], obj);
				} else {
					trace("[DataLoad] Asset batch succesfully loaded.");
					onComplete(obj);
				}
			}
		}
		
		
		/**
		 * Loads all assets listed in the given XML
		 * @param	xml
		 * @param	onComplete
		 * @param	onProgress
		 * @param	onError
		 * @return LoadObject - Tracker object that reflects the status of the load
		 */
		public static function loadAssetsFromXML(xml:XML, onComplete:Function = null, onProgress:Function = null, onError:Function = null):LoadObject{
			var assets:Vector.<AssetInfo> = getAssetsFromXML(xml);
			return loadAssets(assets, onComplete, onProgress, onError);
		}
		
		/**
		 * Loads a file from the given URL. Will cache the asset data so that the file can easily be loaded by ID later on
		 * @param	url -- File path to the given file
		 * @param	type -- Type of file (Use DataType class for apropriate constants)
		 * @param	category -- Category of file (Use DataCategory class for apropriate constants)
		 * @param	uid -- Unique ID. If id already exists it will attempt to load the cached data
		 * @param	onComplete -- Complete callback with a LoaderObject param
		 * @param	onProgress -- Progress callback with a LoaderObject param
		 * @param	onError -- Error callback with a IOErrorEvent param
		 * @return
		 */
		public static function loadFile(url:String, type:String, category:String, uid:String, onComplete:Function = null, onProgress:Function = null , onError:Function = null):LoadObject {
			if (_assetList[uid]) {
				return loadAssetByID(uid, onComplete, onProgress, onError);
			}
			
			var assetInfo:AssetInfo = new AssetInfo
			assetInfo.url = url;
			assetInfo.type = type;
			assetInfo.category = category;
			assetInfo.id = uid;
			_assetList[uid] = assetInfo;
			return loadAssetByID(uid, onComplete, onProgress, onError);
		}
		
		
		/**
		 * Attempts to load an asset
		 * @param	asset
		 * @param	loadObj
		 */
		private static function load(asset:AssetInfo, loadObj:LoadObject):void{
			var loader:Loader;
			var urlLoader:URLLoader;
			var soundLoader:Sound;
			var req:URLRequest  = new URLRequest(asset.url);
			
			
			trace("[DataLoad] Loading asset '" + asset.id +  "' from: " + asset.url);
			if(asset.type == DataType.DISPLAY){
				loader = new Loader;
				
				loader.contentLoaderInfo.addEventListener(ProgressEvent.PROGRESS, loadObj.progress);
				loader.contentLoaderInfo.addEventListener(Event.COMPLETE, onComplete);
				loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, onError);
				
				loader.load(req);
			} else if (asset.type == DataType.SOUND) {
				soundLoader = new Sound;
				
				soundLoader.addEventListener(ProgressEvent.PROGRESS, loadObj.progress);
				soundLoader.addEventListener(Event.COMPLETE, onComplete);
				soundLoader.addEventListener(IOErrorEvent.IO_ERROR, onError);
				
				soundLoader.load(req);
				
			} else {
				urlLoader = new URLLoader;
				urlLoader.addEventListener(ProgressEvent.PROGRESS, loadObj.progress);
				urlLoader.addEventListener(Event.COMPLETE, onComplete);
				urlLoader.addEventListener(IOErrorEvent.IO_ERROR, onError);
				
				urlLoader.load(req);
			}
			
			function onError(e:IOErrorEvent):void{
				trace("[DataLoad] !! There was an error loading this file: " + asset.id + " -> " + asset.url);
				loadObj.error(e);
			}
			
			function onComplete(e:Event):void{
				trace("[DataLoad] Asset '" + asset.id +  "' successfully loaded from: " + asset.url);
				
				if(urlLoader){
					urlLoader.removeEventListener(ProgressEvent.PROGRESS, loadObj.progress);
					urlLoader.removeEventListener(Event.COMPLETE, onComplete);
					urlLoader.removeEventListener(IOErrorEvent.IO_ERROR, loadObj.error);
				}
				
				if(loader){
					loader.contentLoaderInfo.removeEventListener(ProgressEvent.PROGRESS, loadObj.progress);
					loader.contentLoaderInfo.removeEventListener(Event.COMPLETE, onComplete);
					loader.contentLoaderInfo.removeEventListener(IOErrorEvent.IO_ERROR, loadObj.error);
				}
				
				if (soundLoader) {
					soundLoader.removeEventListener(ProgressEvent.PROGRESS, loadObj.progress);
					soundLoader.removeEventListener(Event.COMPLETE, onComplete);
					soundLoader.removeEventListener(IOErrorEvent.IO_ERROR, onError);
				}
				
				loadObj.assetLoaded();
				asset.appDomain = asset.type == DataType.DISPLAY ?  e.currentTarget.applicationDomain : null;
				
				switch(asset.type) {
					case DataType.DISPLAY:
						_assetBank[asset.id] = e.currentTarget.content;
						break;
					case DataType.SOUND:
						_assetBank[asset.id] = soundLoader;
						break
					default:
						_assetBank[asset.id] = e.currentTarget.data;
						break;
				}
				
				loadObj.complete(e);
			}
		}
		
		//====================================================================
		
		// ASSET INTERFACE
		
		//====================================================================
		
		/**
		 * Returns the requested display object
		 * @param	assetID
		 * @return
		 */
		public static function getImage(assetID:String):DisplayObject{
			validateAsset(assetID, DataCategory.IMAGE);
			
			var img:DisplayObject 	= _assetBank[assetID];
			var data:BitmapData   	= new BitmapData(img.width, img.height, true);
			
			data.draw(img);
			
			var bmp:Bitmap		  	= new Bitmap(data);
			var disp:Sprite 		= new Sprite;
			
			disp.addChild(bmp);
			
			return disp;
		}
		
		/**
		 * Returns a bitmap object for the given assetID
		 * @param	assetID
		 * @return
		 */
		public static function getBitmap(assetID:String):Bitmap{
			validateAsset(assetID, DataCategory.IMAGE);
			
			var img:DisplayObject 	= _assetBank[assetID];
			var data:BitmapData   	= new BitmapData(img.width, img.height, true);
			
			data.draw(img);
			
			var bmp:Bitmap		  	= new Bitmap(data);
			
			return bmp;
		}
		
		/**
		 * Returns the bitmapData for the given assetID
		 * @param	assetID
		 * @return
		 */
		public static function getImageData(assetID:String):BitmapData{
			validateAsset(assetID, DataCategory.IMAGE);
			
			var img:DisplayObject 	= _assetBank[assetID];
			var data:BitmapData   	= new BitmapData(img.width, img.height, true);
			
			data.draw(img);
			return data;
		}
		
		/**
		 * Returns a loaded SWF
		 * @param	assetID
		 * @return
		 */
		public static function getSwf(assetID:String):*{
			validateAsset(assetID, DataCategory.SWF);
			var swf:*      = _assetBank[assetID];
			return swf;
		}
		
		/**
		 * Returns exported class definitions contained within a given swf
		 * @param	assetID
		 * @param	linkageName
		 * @return
		 */
		public static function getClass(assetID:String, linkageName:String):Class{
			validateAsset(assetID, DataCategory.SWF);
			var asset:AssetInfo = _assetList[assetID];
			var cls:Class       = asset.appDomain.getDefinition(linkageName) as Class;
			
			return cls;
		}
		
		/**
		 * Returns a loaded XML
		 * @param	assetID
		 * @return
		 */
		public static function getXML(assetID:String):XML{
			validateAsset(assetID, DataCategory.XML);
			return XML(_assetBank[assetID]);
		}
		
		/**
		 * Returns a loaded sound file
		 * @param	assetID
		 * @return
		 */
		public static function getSound(assetID:String):Sound {
			validateAsset(assetID, DataCategory.MP3);
			return Sound(_assetBank[assetID]);
		}
		
		/**
		 * Validates whether or not the asset is available to be accessed
		 * @param	assetID
		 * @param	category
		 */
		private static function validateAsset(assetID:String, category:String):void{
			if(!_assetList[assetID])throw new Error("[DataLoadError] This asset is not defined: " + assetID);
			if(!_assetBank[assetID])throw new Error("[DataLoadError] AssetID: " + assetID + " has not been loaded yet");
			if(!_assetList[assetID].category == category)throw new Error("[DataLoadError] AssetID: " + assetID + " is not a " + category);
		}
		
	}
}