/*
 * Copyright 2016 Frank Breedijk
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
steal(	
	'jquery/controller',
	'jquery/view/ejs',
	'jquery/controller/view',
	'jquery/dom/form_params',
	'seccubus/models',
	'seccubus/finding/table',
	'seccubus/severity/select'
).then( './views/init.ejs', 
function($){

/**
 * @class Seccubus.Issue.Edit
 * @parent Issue
 * @inherits jQuery.Controller
 * Generates an dialog to show/edit one or more issues
 *
 * Story
 * -----
 *  As a user I would like to be able to have a detailed view and edit 
 *  posibility for issues
 */
$.Controller('Seccubus.Issue.Edit',
/** @Static */
{
	/*
	 * @attribute options
	 * Object that contains the options
	 */
	defaults : {
		/* @attribute options.issues
		 * Issue object to edit
		 */
		issue : null,
		/* @attribute options.findings
		 * jQuery query that defines where the findings table will be displayed
		 * Default : null
		 * If this attribute is null there will be no history displayed
		 */
		findings : null,
		/* @attribute options.workspace
		 * Id of the current workspace
		 */
		workspace : -1,
		/* @attribute options.onClear
		 * Function that is called when the cancel button is clicked
		 */
		onClear : function() {
			console.warn("Seccubus.Issue.Edit onClear function called but not set");
		}

	}
},
/** @Prototype */
{
	init : function(){
		this.updateView();
	},
	updateView : function() {
		if ( this.options.workspace == -1 ) {
			alert("Seccubus.Issues.Edit : Workspace not set");
		} else if ( this.options.issue == null ) {
			alert("Seccubus.Issues.Edit : Issue not set");
		} else {
			this.element.html(
				this.view(
					'init',
					this.options.issue
				)
			);
			$('#editIssueSeverity').seccubus_severity_select({
				selected : this.options.issue.severity
			});
		}

		if ( this.options.findings != null ) {
			/* Display the findings for this issue */
			$(this.options.findings).seccubus_finding_table({
				workspace	: this.options.workspace,
				issue		: this.options.issue.id,
				noLink 		: true,
				status 		: "*",
				columns		: [
					"host", "IP", 
					"hostName", "HostName", 
					"port", "Port", 
					"plugin", "Plugin", 
					"scanName","ScanName",
					"severity", "Severity", 
					"find", "Finding",
					"remark", "Remark",
					"status", "Status",
					"", "Action"
				],
				noEdit		: true,
				noLink		: true,
				noFindingUnlink	
							: false,
				noIssueUnlink	
							: true
			});
		}
	},
	".editSetStatus click" : function(el,ev) {
		ev.preventDefault();

		var newState = $(el).attr("newstatus");
		var param = this.element.formParams();
		var issue = this.options.issue;
		
		// Check form
		var ok = true;
		var elements = [];
		if ( param.name == '' ) {
			elements.push("#editIssueName");
			ok = false;
		}

		if ( ok ) {
			issue.attr("name",param.name);
			issue.attr("description",param.description);
			issue.attr("ext_ref",param.ext_ref);
			issue.attr("status",newState)
			issue.attr("workspaceId",this.options.workspace);
			issue.attr("issueId",issue.id);
			issue.attr("severity",param.severity);
			issue.save();
			this.options.onClear();
		} else {
			this.nok(elements);
		}
	},
	nok : function(elements) {
		this.element.children(".nok").removeClass("nok");
		for(i=0;i<elements.length;i++) {
			$(elements[i]).addClass("nok");
		}
		this.element.css({position : "absolute"});
		this.element.animate({left : '+=10'},100);
		this.element.animate({left : '-=20'},100);
		this.element.animate({left : '+=20'},100);
		this.element.animate({left : '-=20'},100);
		this.element.animate({left : '+=20'},100);
		this.element.animate({left : '-=10'},100);
		this.element.css({position : "relative"});
	},	
	/*
	".move click" : function(el,ev) {
		ev.preventDefault();
		this.options.index = $(el).attr("index");
		this.updateView();
	},
	*/
	"{Seccubus.Models.Issue} updated" : function(Issue, ev, issue) {
		this.updateView();
	},
	/* 
	 * Update, overloaded to reder the control after and update even
	 */
	// Autoclear nok status
	".nok change" : function(el) {
		el.removeClass("nok");
	},
	".cancel click" : function(el, ev) {
		ev.preventDefault();
		this.options.onClear();
	},
	update : function(options) {
		this._super(options);
		this.updateView();
	}
})

});
