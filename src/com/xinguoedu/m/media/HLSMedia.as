package com.xinguoedu.m.media
{
	import com.xinguoedu.consts.PlayerState;
	import com.xinguoedu.consts.StreamStatus;
	import com.xinguoedu.evt.EventBus;
	import com.xinguoedu.evt.media.MediaEvt;
	import com.xinguoedu.m.vo.MediaVO;
	
	import flash.media.SoundTransform;
	
	import org.mangui.HLS.HLS;
	import org.mangui.HLS.HLSEvent;
	import org.mangui.HLS.HLSStates;
	import org.mangui.HLS.HLSTypes;
	import org.mangui.HLS.parsing.Level;

	/**
	 * 播放hls视频 
	 * @author yatsen_yang
	 * 
	 */	
	public class HLSMedia extends BaseMedia
	{
		/** Reference to the framework. **/
		protected var _hls : HLS;
		/** Current quality level. **/
		protected var _level : Number;
		/** Reference to the quality levels. **/
		protected var _levels : Vector.<Level>;
	
		private var _seekInLiveDurationThreshold : Number = 60;
		
		/** 是否seek过 **/
		private var _seekFlag:Boolean = false;
		
		public function HLSMedia(mediaType:String)
		{
			super(mediaType);
		}
		
		override public function init(mediaVO:MediaVO):void
		{
			super.init(mediaVO);
			
			_hls = new HLS();
			_hls.addEventListener(HLSEvent.PLAYBACK_COMPLETE, completeHandler);
			_hls.addEventListener(HLSEvent.ERROR, _errorHandler);
			_hls.addEventListener(HLSEvent.MANIFEST_LOADED, manifestHandler);
			_hls.addEventListener(HLSEvent.STATE, stateHandler);
			setVolume(_volume);
		
			super.getVideo();
			_video.attachNetStream(_hls.stream);
			_display.addChild(_video);
		
			_level = 0;
			
			mediaVO.autostart && startLoadAndPlay();
		}
		
		override public function startLoadAndPlay():void
		{
			_hls.load(_mediaVO.url);
			dispatchEvt(StreamStatus.START_LOAD_MEDIA);
		}
		
		/** Forward completes from the framework. **/
		private function completeHandler(event : HLSEvent) : void 
		{
			super.playbackComplete();
		}
		
		/** Forward playback errors from the framework. **/
		private function _errorHandler(event : HLSEvent) : void 
		{
			super.ioErrorHandler();
		}
		
		/** Update video A/R on manifest load. **/
		private function manifestHandler(event : HLSEvent) : void 
		{
			_levels = event.levels;
			// only report position/duration/buffer for VOD playlist and live playlist with duration > _seekInLiveDurationThreshold
			if (_hls.type == HLSTypes.VOD || _levels[0].duration > _seekInLiveDurationThreshold) 
			{
				_duration = _levels[0].duration;
			}
			else 
			{
				_duration = -1;
			}
			
			EventBus.getInstance().dispatchEvent(new MediaEvt(MediaEvt.MEDIA_METADATA, {w:320,h:240}));
			_hls.addEventListener(HLSEvent.MEDIA_TIME, _mediaTimeHandler);
			_hls.stream.play();
		}
		
		/** Update playback position. **/
		private function _mediaTimeHandler(event : HLSEvent) : void 
		{
			// only report position/duration/buffer for VOD playlist and live playlist with duration > _seekInLiveDurationThreshold
			if (_hls.type == HLSTypes.VOD || event.mediatime.duration > _seekInLiveDurationThreshold) 
			{
				_duration = event.mediatime.duration;
				_pos = event.mediatime.position;
				_bufferPercent = (_pos + event.mediatime.buffer) / event.mediatime.duration;

				EventBus.getInstance().dispatchEvent(new MediaEvt(MediaEvt.MEDIA_TIME, 
					{
						position: _pos, 
						duration: _duration, 
						bufferDuration:_bufferPercent*_duration
					}));
				
				checkIsNearlyComplete(_duration, _pos);
			}
			
		}
		
		private function stateHandler(event : HLSEvent) : void 
		{
			switch(event.state) 
			{
				case HLSStates.IDLE:
					dispatchMediaStateEvt(PlayerState.IDLE);
					break;
				case HLSStates.PLAYING_BUFFERING:
				case HLSStates.PAUSED_BUFFERING:
					dispatchMediaStateEvt(PlayerState.BUFFERING);
					break;
				case HLSStates.PLAYING:
					dispatchMediaStateEvt(PlayerState.PLAYING);
					break;
				case HLSStates.PAUSED:
					dispatchMediaStateEvt(PlayerState.PAUSED);
					break;
			}
		}
		
		override public function play():void
		{
			if(_isComplete)
				_hls.load(_mediaVO.url);
			else
				_hls.stream.resume();
			
			super.play();
		}
		
		override public function pause():void
		{
			_hls.stream.pause();
		}
		
		override public function seek(sec:Number):void
		{
			checkIsNearlyComplete(_duration, sec, true);
			_hls.stream.seek(sec);
		}
		
		/**
		 * 设置视频的音量 
		 * @param volume 音量大小
		 * 
		 */		
		override public function setVolume(volume:int):void
		{
			if(_hls.stream.soundTransform.volume * 100 != volume)
			{
				_hls.stream.soundTransform = new SoundTransform(volume / 100);
			}
		}
	}
}