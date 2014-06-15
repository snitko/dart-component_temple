part of component_temple;

class TemplateStack {

  static Map templates = new Map();

  static collect(fragment) {
    fragment.querySelectorAll('templates>template').forEach((t) {
      TemplateStack.templates[t.attributes['name']] = new Template(t);
    });
  }

  static buildComponents(container, [parent_component=null]) {
    TemplateStack.templates.forEach((k,t) {
      t.buildComponents(container, parent_component);
    });
  }

  static findComponentForDomElement(el) {
    var component;
    var component_name = el.dataset['componentName'];
    var template_name  = component_name.split('_')[0];
    TemplateStack.templates.forEach((k,t) {
      if(t.name == template_name) {
        t.components.forEach((c_name, c_instance) {
          if(c_name == component_name) { component = c_instance; }   
        });
      }
    });
    return component;
  }

}
