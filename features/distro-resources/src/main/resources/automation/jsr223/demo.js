'use strict';

scriptExtension.importPreset("RuleSupport");
scriptExtension.importPreset("RuleSimple");

var sRule = new SimpleRule() {
    execute: function( module, input) {
        print("This is a 'hello world!' from a Javascript rule.");
    }
};

sRule.setTriggers([
        new Trigger(
            "aTimerTrigger", 
            "timer.GenericCronTrigger", 
            new Configuration({
                "cronExpression": "0 * * * * ?"
            })
        )
    ]);

automationManager.addRule(sRule);
