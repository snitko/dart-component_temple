part of component_temple;

class Template {

  static NodeValidatorBuilder nodeValidator() {
    return new NodeValidatorBuilder()
      ..allowHtml5()
      ..allowElement('div',  attributes: ['data-component-id'      ])
      ..allowElement('div',  attributes: ['data-component-content' ])
      ..allowElement('div',  attributes: ['data-event-listener'    ])
      ..allowElement('input', attributes: ['data-event-listener'    ])
      ..allowElement('div',  attributes: ['data-component-children'])
      ..allowElement('span', attributes: ['data-component-property']);
  }

  static final Map componentClasses = findSubclasses("Component");

  Element   element              ;
  String    html                 ;
  String    name                 ;
  Component componentClass       ;
  String    componentClassName   ;
  Map       components = {}      ;
  num       last_component_id = 0;
  String    numeration_type = 'consecutive';

  Template(this.element) {

    this.html = this.element.innerHtml;
    this.name = capitalizeFirstLetter(this.element.attributes['name']);

    if(this.element.dataset['numerationType'] != null) {
      this.numeration_type = this.element.dataset['numerationType'];
    }

    /*****************************************************/
    /* Determining Component subclass for this template. */

    /* Sometimes you want your template to have a different name, but use the same Component subclass.
       So you simply add a component-class-name attr to it. Usecase would be a button of a different color.
    */
    if(this.element.attributes['component-class-name'] != null) {
      this.componentClassName = "${capitalizeFirstLetter(this.element.attributes['component-class-name'])}Component";
    } else {
      this.componentClassName = "${dashedToCamelcase(this.name)}Component";
    }

    // If no custom Component subclass for this template found, use Component
    try {
      this.componentClass = componentClasses
        .firstWhere((cm) => cm.simpleName == new Symbol(this.componentClassName));
    } on StateError {
      this.componentClass     = reflectClass(Component);
      this.componentClassName = 'Component';
    }

    /***************************************************/
    /***************************************************/

  }

  buildComponents(container, [parent_component=null]) {

    container.children.forEach((c) {

      var node_name = dashedToCamelcase(c.nodeName.toLowerCase());

      if(c.nodeType == 1) {
        
        // It's our component - let's build it! 
        if(node_name == this.name) {
          var component = this.componentClass.newInstance(new Symbol(''), [this, c]).reflectee;
          if(parent_component != null) component.parent = parent_component;
          addComponent(component);
          TemplateStack.buildComponents(component.element, component);
        }

        // Not a component at all, regular element - let's look inside!
        else if (!TemplateStack.templates.keys.contains(downcaseFirstLetter(node_name)) && c.dataset['componentName'] == null) {
          buildComponents(c, parent_component);
        }

      }
    });

  }

  addComponent(c) {
    this.components[c.name] = c;
    if(numeration_type != 'random') { this.last_component_id += 1; }
  }

  buildDomElement() {

    var dom_element;
    try {
      dom_element = new Element.html(this.html, validator: Template.nodeValidator());
    } catch(e) {
      if(e.message == "More than one element") {
        throw new Exception("Template ${this.name} has more than one immediate DOM-child. Templates must have only one child DOM element.");
      }
    }

    return dom_element;

  }

  next_component_number() {
    if(numeration_type == 'random')
      return _generateAltNumeration();
    else
      return last_component_id+1;
  }

  _generateAltNumeration() {
    var t = new DateTime.now().millisecondsSinceEpoch;
    var r = new Random().nextInt(1000000); 
    return("${t}-${r}");
  }

}
