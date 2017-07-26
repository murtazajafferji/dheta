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

var JSONPFetcher = function JSONPFetcher() {};
JSONPFetcher.prototype = new Fetcher();
JSONPFetcher.prototype.LABEL_VERB = LoadingView.prototype.LABEL_DOWNLOADING;
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
  this.downloader.fetcher = this;
  this.downloader.requestData(url);
};

var FacebookFetcher = function FacebookFetcher(opts) {
  this.types = ['wiki', 'facebook'];
};
FacebookFetcher.prototype = new JSONPFetcher();
FacebookFetcher.prototype.FACEBOOK_API_URL = '/cloud/facebook';
FacebookFetcher.prototype.data = [];
FacebookFetcher.prototype.currentDataset = 0;
FacebookFetcher.prototype.getData = function wf_getData(dataType, data) {
  $.ajax({
    type: 'GET', 
    url: this.FACEBOOK_API_URL, 
    data: { page_id: data }, 
    context: this,
    dataType: 'json',
    success: function(data){
      this.data = data;
      this.handleResponse(this.data[this.currentDataset]);
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
FacebookFetcher.prototype.changeDataset = function wf_changeDataset() {
  if (this.currentDataset + 1 == this.data.length){
    this.currentDataset = 0;
  } else {
    this.currentDataset++;
  }
  this.handleResponse(this.data[this.currentDataset]);
};