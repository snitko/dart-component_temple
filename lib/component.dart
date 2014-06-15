part of component_temple;

class Component extends Object with observable.Subscriber, observable.Publisher, Attributable {

  static NodeValidatorBuilder childNodeValidator(tag_name) {
    return new NodeValidatorBuilder()
      ..allowHtml5()
      ..allowElement(tag_name);
  }

  /*********************************************************************************************/
  /* Instance variables declarations */
  /*********************************************************************************************/

  Element   element  ; // DOM element which corresponds to the current object
  Element   content  ; // DOM element which holds the {{content}} of the element
  Template  template ; // our Template object we're going to use to generate an element
  Component _parent  ; // another Component which is a parent of the current one (could be null)
  String    _name    ; // a combination of unique id and a name of the component, for instance Button_1
                       // could also be set by user and be whatever.
  
  /* Roles determine what a parent does with events from components.
     A role may be defined in html by adding `data-component-role` attribute.
  */
  String role = 'any';

  Map virtual_containers = {};

  var _model; // We don't really want to specify class name here and require TempleModel library;
              // It's better to have more freedom.
  
  /* Each value of this map holds a child with a specific role, while keys are role names.
     It is not supposed to be accessed directly (but it has to be public, cos for some reason
     subclasses in Dart don't recognize superclass instance vars that start with _.
     Anyway, a proper way to access children is by using a children() getter - note how () at the end
     are obligatory.
  */
  Map children_by_roles = {};

  /* This is how you list attributes for your component. They are not real properties. Instead,
     getters and setters are dynamic (caught by noSuchMethod). This is helpful because
     we want to be able to execute callbacks on attribute change.
  */
  final List attribute_names = ['caption'];
        Map  attributes      = {};

  /* When an attribute is updated, these are the callbacks that get invoked.
     There's only one default one and it updates the corresponding DOM element with the
     new value. You can either redefine it or add your own callbacks for each
     particular attribute.

     `self_mirror` argument is a mirror of the current object. We can't simply pass
     `this`, because this raises an exception.
  */
  final Map attribute_callbacks = {
    'default' : (attr_name, self) => self.updateProperty(attr_name)
  };

  /* This is where events are defined.
     If you don't want this Element do anything on the event, but still want its parent
     to be notified, use null as a value for the key (a key represents an event name).
  */
  final Map event_handlers = {
    
    'click' : null, // Still notify the parent of the click event.

    'model.update' : (self, model) {
      self.attribute_names.forEach((attr_name) {
        if(model.attribute_names.contains(attr_name))
          self.attributes[attr_name] = model.attributes[attr_name];
      });
      self.updateElement();
    }

  };

  /* Components may consist of several DOM elemnts, and each may be able to trigger an event.
     This event is caught here and then we can decide what custom event in our component is
     then called.

     They key of the map is a selector used to find a an element withing the component with
     querySelectorAll(). The value is another Map: they key is name of the DOM event, the value
     is the name of the Component event that's going to be called.
  */
  final Map internal_event_handlers = {};

  /* There's no reason to save those Streams yet, but we may later need to be able
     to cancel event listeners, so let's do it.
  */
  Map event_listeners = {};

  /* Put things like making a Button inactive or animation in here.
     Basic Component is dumb, cannot behave itself.
  */
  final Map behaviors = {};


  /*********************************************************************************************/
  /* Constructors */
  /*********************************************************************************************/

  /* Used by Template objects only */
  Component(this.template, this.element) {
    _shared_constructor();
  }

  /* Used to create components dynamically from code */
  Component.build(Map properties) {

    if(properties['template_name'] == null) {
      properties['template_name'] = downcaseFirstLetter(MirrorSystem.getName(reflect(this).type.simpleName).replaceFirst('Component', ''));
    }

    if(properties['role'] == null)
      properties['role'] = 'any';

    this.role     = properties['role'];
    this.template = TemplateStack.templates[properties['template_name']];
    this.element  = new Element.html("<${this.template.name}></${this.template.name}>", validator: Component.childNodeValidator(properties['template_name']));
    this._name    = properties['name'];
    _shared_constructor();
    this.template.addComponent(this);
  }

  _shared_constructor() {

    _setDefaultProperties();

    if(this.name == null) {
      if(this.element.dataset['componentName'] != null) {
        this._name = this.element.dataset['componentName'];
      } else {
        this._name = "${this.template.name}_${this.template.next_component_number()}";
      }
    }
    
    if(this.element.dataset['componentRole'] != null) {
      this.role = this.element.dataset['componentRole'];
    }
  
    var template_element = this.template.buildDomElement();
    this.content = new DOMVirtualContainer.find('Component_content', template_element, skip_children: ['data-component-name']);
    if(this.content != null) {
      this.element.childNodes.forEach((n) {
        this.content.append(n.clone(true));
      });
    }

    prvt_replaceDomElementWithTemplate(template_element);
    updateElement();
    _setDOMEventListeners();

  }

  /*********************************************************************************************/
  /* Custom getters and setters */
  /*********************************************************************************************/

  get parent => _parent;
  set parent(Component p) {
    setParent(p);
    if(parent.children_by_roles[this.role] == null) { parent.children_by_roles[this.role] = []; }
    parent.children_by_roles[this.role].add(this);  
  }

  /* This is for cases where we want to set a parent, but then manually add
     a child to the children's list.
  */
  setParent(Component p) {
    _parent = p;
    // Whenever we add a parent, it becomes a subscriber to all the events happening in this view.
    addObservingSubscriber(p);
  }

  get name => _name;
  set name(String new_name) {
    // Probably later this should be allowed
    // but for now it's too much work: change DOM element data attr,
    // change Template's component Map name etc.
    throw new Exception("You cannot change component's name after it was already built.");
  }

  /* Subscribes this Component to the model's events and immediately
     invokes 'model.update' callback to sync with model attributes
  */
  get model => _model;
  set model(m) {

    if(!(m is observable.Publisher) || !(m is Attributable))
      throw new Exception("Model must implement observable.Publisher and Attributable interfaces!");

    m.addObservingSubscriber(reflect(this).reflectee);
    captureEvent('model.update', m)                   ;
    _model = m;

  }

  /* Returns children of specific roles or all children.
     Always use () when calling this getter, because it's not actually a getter,
     but philosophically it is.
  */
  children([role]) {
    if(role == null || role == 'any') {
      var result = [];
      children_by_roles.forEach((k,v) {
        result.addAll(v);
      });
      return result;
    } else {
      return children_by_roles[role];
    }
  }

  /*********************************************************************************************/
  /*  Public Methods */
  /*********************************************************************************************/

  addChild(Component child, [Function f]) {
    child.parent = this;
    if(f != null) {
      f(child);
    } else {
      addChildToDOM(child);
    }
  }

  addChildToDOM(Component child) {
    var children_container = _getFirstVirtualContainer("children:${child.role}");
    if(children_container != null) { children_container.append(child.element); }
  }

  remove() {
    this.children().forEach((c) => c.remove());   // remove children before removing itself!
    if(this.parent != null)
      this.parent.prvt_removeChild(reflect(this).reflectee);
    this.template.components.remove(this.name);
    this.element.remove();
    this.element = null;
    if(model != null) {
      model.removeObservingSubscriber(this);
      model = null;
    }
  }
  
  /* Updates the property container of a DOM element */
  updateProperty(property_name, [value=null]) {

    if(value == null)
      value = getAttributeAsString(property_name);

    var property_containers = _getVirtualContainers('property:${property_name}');
    property_containers.forEach((c) => c.text = value);

  }
  
  /* Calls for attributes callbacks for each attribute and, supposedly,
     updates property containers in a DOM element. Of course, that is the default
     behavior when an attribute is updated, but it can be changed if another
     callback is assigned.
  */
  updateElement() {
    attribute_names.forEach((attr_name) {
      invokeAttributeCallback(attr_name);
    });
  }

  getAttributeAsString(attr_name) {
    var value = attributes[attr_name];
    if(value == null)           { value = '';               }
    else if(!(value is String)) { value = value.toString(); }
    return value;
  }

  behave(b) {
    if(this.behaviors[b] != null) {
      this.behaviors[b](this.element);
    } else {
      throw new Exception("No behavior `${b}` defined for ${this.template.componentClassName}");
    }
  }

  /*********************************************************************************************/
  /*  Private Methods */
  /*********************************************************************************************/

  /* Extracts property values from component's custom html element attributes and assigns them to
     to properties of the object. Can only be called from constructor, since the element
     gets replaced.
  */
  _setDefaultProperties() {

    this.element.dataset.forEach((k,v) {
      var property_name = downcaseFirstLetter(k.replaceAll('property', ''));
      if(attribute_names.contains(property_name)) {
        attributes[property_name] = v;
      }
    });

  }

  _propertyElements([property_name=null]) {
    if(property_name == null) {
      return _getVirtualContainers("property.*");
    } else {
      return _getVirtualContainers("property:${property_name}");
    }
  }

  /* Do not use this method anywhere. It should only be used by remove() method of the child.
     That's because a child is only removed from the children_by_roles list, but not from the DOM.
  */
  prvt_removeChild(Component child) {
    if(children_by_roles[child.role] != null)
      children_by_roles[child.role].remove(child);
  }
  
  /* This only called from constructor and is for cases when we want to redefine
     it in subclasses. It may sometimes be required. Like for example when it is impossible
     to create a template element whose root element is <tr>. Instead, such an element must be wrapped
     in <table>, then in a subclass which handles the template this <tr> would extracted from
     the <table> and insrted into the DOM - this would happen in this redefined method.
  */
  prvt_replaceDomElementWithTemplate(template_element) {
    template_element.dataset['componentName'] = this.name;
    this.element.replaceWith(template_element); // Replacing element in the DOM
    this.element = template_element           ; // Replacing element in component instance
  }

  _getVirtualContainers(container_name) {
    if(virtual_containers[container_name] == null)
      virtual_containers[container_name] = new DOMVirtualContainer.findAll('Component_${container_name}', this.element, skip_children: ['data-component-name']);
    return virtual_containers[container_name];
  }

  _getFirstVirtualContainer(container_name) {
    return new DOMVirtualContainer.find('Component_${container_name}', this.element, skip_children: ['data-component-name']);
  }

  _setDOMEventListeners() {
    
    event_handlers.forEach((k,v) {
      // Only set those listeners whose event names don't have a dot in them,
      // which indicates those are reserved for children.
      if(!k.contains('.')) {
        event_listeners[k] = element.on[k].listen((event) {
          event.stopPropagation();
          captureEvent(k);
        });
      }

      internal_event_handlers.forEach((el_query, el_events) {
        element.querySelectorAll("${el_query}").forEach((el) {
          el_events.forEach((e,h) {
            el.on[e].listen((event) {
              event.stopPropagation();
              captureEvent(h);
            });
          });
        });
      });

    });
  }


  /*********************************************************************************************/
  /*  Everything else */
  /*********************************************************************************************/

  noSuchMethod(Invocation i) {  
    var result = prvt_noSuchGetterOrSetter(i);
    if(result != false)
      return result;
    else
      super.noSuchMethod(i);
  }

}
