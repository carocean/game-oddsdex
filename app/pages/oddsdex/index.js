//@layout=layout.html

module.exports = (function async(req, res, _, $) {
    _('.container').html($('div').prop('outerHTML'));
    var html = _('html').html();
    res.write(html);
});