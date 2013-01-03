steal(	'jquery/controller',
	'jquery/view/ejs',
	'jquery/dom/form_params',
	'jquery/controller/view',
	'seccubus/models',
	'seccubus/event/select'
).then(	'./views/init.ejs',
	function($){

/**
 * @class Seccubus.Notification.Edit
 * @parent Notification
 * @inherits jQuery.Controller
 * Generates a dialog to edit a notification
 *
 * Story
 * -----
 * As a user I would like to be able to edit notifications from the GUI
 */
$.Controller('Seccubus.Notification.Edit',
/** @Static */
{
	/*
	 * @attribute options
	 * Object that contains the options
	 */
	defaults : {
		/*
		 * @attribute options.onClear
		 * Funciton that is called when the form is cleared, e.g. to 
		 * disable a modal display
		 */
		onClear : function () { },
		/* attribute options.notification
		 * Notification object that needs to be edited
		 */
		notification : null
	}
},
/** @Prototype */
{
	init : function(){
		this.updateView();
	},
	updateView : function() {
		this.element.html(
			this.view(
				'init',
				this.options.notification
			)
		);
		$('#editNotTrigger').seccubus_event_select({
			selected : this.options.notification.event_id
		});
	},
	submit : function(el, ev){
		ev.preventDefault();

		var params = el.formParams();
		var ok = true;
		var elements = [];
		if ( params.subject == '' ) {
			elements.push("#editNotSubject");
			ok = false;
		}
		if ( params.recipients == '' ) {
			elements.push("#editNotRecipients");
			ok = false;
		}
		if ( params.message == '' ) {
			elements.push("#editNotMessage");
			ok = false;
		}
		if ( ok ) {
			this.element.find('[type=submit]').val('Updating...')

			notification = this.options.notification;
			notification.subject = params.subject;
			notification.event_id = params.trigger;
			notification.recipients = params.recipients;
			notification.message = params.message;

			notification.save(this.callback('saved'));
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
		this.element.animate({left : '+=20'},100);
		this.element.animate({left : '-=20'},100);
		this.element.animate({left : '+=20'},100);
		this.element.animate({left : '-=20'},100);
		this.element.animate({left : '+=20'},100);
		this.element.animate({left : '-=20'},100);
		this.element.css({position : "relative"});
	},
	".cancel click" : function() {
		this.clearAll();
	},
	saved : function(){
		this.clearAll();
	},
	clearAll : function() {
		this.element.find('[type=submit]').val('Update Notification');
		this.element[0].reset()
		$(".nok").removeClass("nok");
		this.options.onClear();
	},
	".nok change" : function(el) {
		el.removeClass("nok");
	},
	update : function(options) {
		this._super(options);
		this.updateView();
	}
})

});
