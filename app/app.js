const http = require('http');
const jsdom = require('jsdom');
const nReadlines = require('n-readlines');
const $ = require('jquery');
var rf = require("fs");

http.createServer(async (req, res) => {
  var url = req.url;
  var pos = url.lastIndexOf('?');
  var uri = url;
  var qs = '';
  if (pos > -1) {
    uri = uri.substring(0, pos);
    qs = uri.substring(pos + 1);
  }
  if (uri == null || uri == '' || uri == '/') {
    uri = '/index';
  }
  if (uri.startsWith("/api/")) {
    await callApi(uri, req, res);
    return;
  }
  if (/\w+\.\w+$/ig.test(uri)) {
    var file = __dirname + uri;
    try {
      var data = rf.readFileSync(file, "utf-8");
      rf.close;
      res.end(data);
      return;
    } catch (e) {
      res.statusCode = 404;
      res.statusMessage = 'File Not Found!';
      res.end();
      return;
    }
  }
  var page = require('.' + uri + '.js');
  res.setHeader('Content-Type', 'text/html; charset=utf-8')

  if (typeof page == 'undefined' || typeof page != 'function') {
    res.statusCode = 404;
    res.statusMessage = 'File Not Found!';
    res.end();
    return;
  }
  const lineReader = new nReadlines(__dirname + uri + '.js');
  var line = '';
  while (line = lineReader.next()) {
    if (line == null || line == '' || typeof line == 'undefined') {
      continue;
    }
    var header = line.toString('utf-8');
    var reg = /^\/\/\s*@layout\s*=\s*(\w+\.html)\s*$/ig;
    var layoutFileName = '';
    if (reg.test(header)) {
      layoutFileName = RegExp.$1;
    }
    break;
  }

  const { JSDOM } = jsdom;
  var layoutDom;
  if (layoutFileName != '' && layoutFileName != null && typeof layoutFileName != 'undefined') {
    //有模板
    var htmlFile = __dirname + '/layout/' + layoutFileName;
    layoutDom = await JSDOM.fromFile(htmlFile, {
      contentType: "text/html; charset=utf-8"
    });
  } else {
    layoutDom = new JSDOM('<!DOCTYPE html><body></body></html>');
  }
  var htmlFile = __dirname + uri + '.html';
  let partDom;
  try {
    partDom = await JSDOM.fromFile(htmlFile, {
      contentType: "text/html; charset=utf-8"
    });
  } catch (e) {
    partDom = new JSDOM('<!DOCTYPE html><body></body></html>');
  }
  const part = $(partDom.window);
  const layout = $(layoutDom.window);
  layout('head').append(part('script'));
  layout('head').append(part('link'));
  // res.write('<!DOCTYPE html>');
  try {
    await page(req, res, layout, part);
    res.statusCode = 200;
    res.statusMessage = 'ok';
    res.end();
  } catch (e) {
    console.log(e);
    res.statusCode = 500;
    res.statusMessage = e + '';
    res.end();
    return;
  }
}).listen(8080, () => {
  console.log(`Server is running on port 8080`);
})

const callApi = async function (uri, req, res) {
  var fileName = '';
  var pos = uri.lastIndexOf('/');
  var path = '';
  if (pos < 0) {
    fileName = uri;
  } else {
    fileName = uri.substring(pos + 1);
    path = uri.substring(0, pos);
  }
  if (path == '') {
    path == '/';
  }
  var ext = 'index';
  var fnWithoutExt = '';
  pos = fileName.lastIndexOf('.');
  if (pos > -1) {
    ext = fileName.substring(pos + 1);
    fnWithoutExt = fileName.substring(0, pos);
  } else {
    fnWithoutExt = fileName;
  }
  var url = '.' + path +'/'+ fnWithoutExt + '.js';
  try {
    var api = require(url);
    res.setHeader('Content-Type', 'text/html; charset=utf-8')
    await api[ext](req, res);
    res.statusCode = 200;
    res.statusMessage = 'ok';
    res.end();
  } catch (e) {
    console.log(e);
    res.statusCode = 500;
    res.statusMessage = e + '';
    res.end();
  }
}