//
//  Action.js
//  QuickShotAction
//
//  Created by Тигран Закарян on 03.05.26.
//

var Action = function() {};

Action.prototype = {
    run: function(arguments) {
        var html = document.documentElement ? document.documentElement.outerHTML : "";
        var title = document.title || "Document";
        var url = document.location ? document.location.href : "";

        arguments.completionFunction({
            html: html,
            title: title,
            url: url
        });
    },

    finalize: function(arguments) {
        // No-op. PDF conversion is completed in native code.
    }
};

var ExtensionPreprocessingJS = new Action();
