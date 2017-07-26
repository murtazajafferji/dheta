'use strict';

/* global LoadingView, _ */

var Fetcher = function Fetcher() { };
Fetcher.prototype.LABEL_VERB = LoadingView.prototype.LABEL_LOADING;

var TextFetcher = function TextFetcher() {
  this.types = ['text', 'base64'];
};
TextFetcher.prototype = new Fetcher();
TextFetcher.prototype.stop = function tf_stop() {
  clearTimeout(this.timer);
};
TextFetcher.prototype.getData = function tf_getData(dataType, data) {
  if (dataType === 'text' && !data) {
    data = this.app.views['source-dialog'].panels.cp.textareaElement.value;
  } else if (dataType === 'base64') {
    data = decodeURIComponent(escape(window.atob(data)));
  } else {
    data = decodeURIComponent(data);
  }

  // Make sure we call the handler methods as async callback.
  this.timer = setTimeout((function tf_gotData() {
    this.app.handleData(data);
  }).bind(this), 0);
};

var ListFetcher = function ListFetcher() {
  this.types = ['list', 'base64-list'];
};
ListFetcher.prototype = new Fetcher();
ListFetcher.prototype.stop = function lf_stop() {
  clearTimeout(this.timer);
};
ListFetcher.prototype.getData = function lf_getData(dataType, data) {
  var text;
  if (dataType === 'list' && !data) {
    text = this.app.views['list-dialog'].textElement.value;
  } else if (dataType === 'base64-list') {
    text = decodeURIComponent(escape(window.atob(data)));
  } else {
    text = decodeURIComponent(data);
  }

  var vol = 0;
  var list = [];
  text.split('\n').forEach(function eachItem(line) {
    var item = line.split('\t').reverse();
    if (!line || !item[0] || !item[1]) {
      return;
    }

    item[1] = parseInt(item[1], 10);
    if (isNaN(item[1])) {
      return;
    }

    vol += item[0].length * item[1] * item[1];
    list.push(item);
  });

  // Make sure we call the handler methods as async callback.
  this.timer = setTimeout((function bf_gotData() {
    this.app.handleList(list, vol);
  }).bind(this), 0);
};

var JSONPScriptDownloader = function JSONPScriptDownloader() {};
JSONPScriptDownloader.prototype.CALLBACK_PREFIX = 'JSONPCallbackX';
JSONPScriptDownloader.prototype.reset =
JSONPScriptDownloader.prototype.stop = function jpf_stop() {
  this.currentRequest = undefined;
  clearTimeout(this.timer);
};
JSONPScriptDownloader.prototype.handleEvent = function(evt) {
  var el = evt.target;
  window[el.getAttribute('data-callback-name')] = undefined;
  this.currentRequest = undefined;
  clearTimeout(this.timer);

  el.parentNode.removeChild(el);

  if (evt.type === 'error') {
    this.fetcher.handleResponse();
  }
};
JSONPScriptDownloader.prototype.getNewCallbackName = function() {
  // Create a unique callback name for this request.
  var callbackName = this.CALLBACK_PREFIX +
    Math.random().toString(36).substr(2, 8).toUpperCase();

  // Install the callback
  window[callbackName] = (function() {
    // Ignore any response that is not coming from the currentRequest.
    if (this.currentRequest !== callbackName) {
      return;
    }
    this.currentRequest = undefined;
    clearTimeout(this.timer);

    // send the callback name and the data back
    this.fetcher.handleResponse.apply(this.fetcher, arguments);
  }).bind(this);

    return callbackName;
  };
JSONPScriptDownloader.prototype.requestData = function(url) {
  var callbackName = this.currentRequest = this.getNewCallbackName();

  url += (url.indexOf('?') === -1) ? '?' : '&';
  url += 'callback=' + callbackName;

  var el = this.scriptElement = document.createElement('script');
  el.src = url;
  el.setAttribute('data-callback-name', callbackName);
  el.addEventListener('load', this);
  el.addEventListener('error', this);

  document.documentElement.firstElementChild.appendChild(el);

  clearTimeout(this.timer);
  this.timer = setTimeout(function jpf_timeout() {
    window[callbackName]();
  }, this.fetcher.TIMEOUT);
};

var JSONPWorkerDownloader = function JSONPWorkerDownloader() {};
JSONPWorkerDownloader.prototype.PATH = './word_cloud/assets/';
JSONPWorkerDownloader.prototype.reset =
JSONPWorkerDownloader.prototype.stop = function jpf_stop() {
  if (!this.worker) {
    return;
  }

  clearTimeout(this.timer);
  this.worker.terminate();
  this.worker = null;
};
JSONPWorkerDownloader.prototype.requestData = function(url) {
  if (this.worker) {
    this.stop();
  }

  this.worker = new Worker(this.PATH + 'downloader-worker.js');
  this.worker.addEventListener('message', this);
  this.worker.addEventListener('error', this);
  this.worker.postMessage(url);

  clearTimeout(this.timer);
  this.timer = setTimeout((function() {
    this.stop();
    this.fetcher.handleResponse();
  }).bind(this), this.fetcher.TIMEOUT);
};
JSONPWorkerDownloader.prototype.handleEvent = function(evt) {
  var data;
  switch (evt.type) {
    case 'message':
      data = evt.data;

      break;

    case 'error':
      data = [];
      // Stop error event on window.
      evt.preventDefault();

      break;
  }
  this.stop();
  this.fetcher.handleResponse.apply(this.fetcher, data);
};

var JSONPFetcher = function JSONPFetcher() {};
JSONPFetcher.prototype = new Fetcher();
JSONPFetcher.prototype.LABEL_VERB = LoadingView.prototype.LABEL_DOWNLOADING;
JSONPFetcher.prototype.USE_WORKER_WHEN_AVAILABLE = true;
JSONPFetcher.prototype.TIMEOUT = 30 * 1000;
JSONPFetcher.prototype.reset = function jpf_reset() {
  if (this.downloader) {
    this.downloader.reset();
  }
};
JSONPFetcher.prototype.stop = function jpf_stop() {
  if (this.downloader) {
    this.downloader.stop();
  }
  this.downloader = null;
};
JSONPFetcher.prototype.requestData = function jpf_requestJSONData(url) {
  if (this.USE_WORKER_WHEN_AVAILABLE && window.Worker) {
    this.downloader = new JSONPWorkerDownloader();
  } else {
    this.downloader = new JSONPScriptDownloader();
  }

  this.downloader.fetcher = this;
  this.downloader.requestData(url);
};

var FacebookFetcher = function FacebookFetcher(opts) {
  this.types = ['wiki', 'facebook'];
};
FacebookFetcher.prototype = new JSONPFetcher();
FacebookFetcher.prototype.FACEBOOK_API_URL =
  '/cloud/facebook';
FacebookFetcher.prototype.getData = function wf_getData(dataType, data) {
  $.ajax({
    type: 'GET', 
    url: this.FACEBOOK_API_URL, 
    data: { page_id: data }, 
    context: this,
    dataType: 'json',
    success: function(data){
      this.handleResponse(data);
    }
  });
};
FacebookFetcher.prototype.handleResponse = function wf_handleResponse(res) {
  var scores = res;
  var vol = 0;
  var list = [];
  for (var key in scores) {
    vol += key.length * scores[key] * scores[key];
    list.push([key, scores[key]]);
  };

  // Make sure we call the handler methods as async callback.
  this.timer = setTimeout((function bf_gotData() {
    this.app.handleList(list, vol, _('facebook-title', { title: "Response from my endpoint" }));
  }).bind(this), 0);
};