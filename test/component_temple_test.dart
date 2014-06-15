import 'dart:html';
import 'dart:mirrors';
import 'package:unittest/unittest.dart';
import 'package:unittest/html_config.dart';
import '../lib/component_temple.dart';

import 'package:attributable/attributable.dart';
import 'package:observable_roles/observable_roles.dart';
import 'package:validatable/validatable.dart';

class ButtonComponent extends Component {

  ButtonComponent(template, element)    : super(template, element);
  ButtonComponent.build(Map properties) : super.build(properties);

}

class ValidatableComponent extends Component with Validatable {

  ValidatableComponent(template, element)    : super(template, element);
  ValidatableComponent.build(Map properties) : super.build(properties);

  final List attribute_names = ['attr1', 'attr2'];

  final Map validations = {
    'attr1' : { 'isLessThan'   : 10 },
    'attr2' : { 'isLongerThan' : 5  }
  };

}

class CaptionAsContentButtonComponent extends Component {

  CaptionAsContentButtonComponent(template, element) : super(template, element);

  final Map attribute_callbacks = {
    'default' : (attr_name, self) => self.updateProperty(attr_name),
    'caption' : (attr_name, self) => self.content.text = self.getAttributeAsString(attr_name)
  };

}

class MockComponent extends Component {

  final Map internal_event_handlers = {
    '.clickableStuff' : { 'click' : 'increment_counter' }
  };

  final Map event_handlers = {
    'click'             : null,
    'increment_counter' : null
  };

  List mock_calls = [];
  MockComponent(template, element) : super(template, element);

  @override captureEvent(event, [Publisher p]) {
    mock_calls.add("called captureEvent() with $event");
    super.captureEvent(event, p);
  }

}

class DummyModel extends Object with Attributable, Publisher {

  final List attribute_names = ['caption'];

  get caption    => attributes['caption']    ;
  set caption(v) => attributes['caption'] = v;

}


main() {

  useHtmlConfiguration();

  TemplateStack.collect(document);
  TemplateStack.buildComponents(document.querySelector('body'));

  group('TemplateStack', () {
  
    test('creates instances of Template for all found templates', () {
      expect(TemplateStack.templates.length, equals(8));
      TemplateStack.templates.forEach((k,v) => expect((v is Template), isTrue));
    });

    test('assigns child components to parents', () {
      var nested_button    = TemplateStack.templates['button'].components['Button_4'];
      var button_container = TemplateStack.templates['buttonContainer'].components['ButtonContainer_1'];
      expect(nested_button.parent,             equals(button_container));
      expect(button_container.children().length, equals(2)             );
      expect(button_container.children()[0],     equals(nested_button) );
    });

  });

  group('Template', () {

    test('creates components out of itself from appropriate subclassess of Component', () {

      /* Note that here we're checking for 4 buttons and 1 greenButton,
         but 5 div.button elements. Look inside runner.html! I'm checking that
         a template by the name greenButton still uses ButtonComponent class because
         its attribute `component-class-name` is set to 'button'.
      */      
      expect(TemplateStack.templates['button'].components.length, equals(5));
      expect(TemplateStack.templates['greenButton'].components.length, equals(1));
      expect(document.querySelectorAll('div.button').length, equals(6));
      
      TemplateStack.templates['button'].components.forEach((k,v) {
        ClassMirror component_class = reflect(v).type;
        expect(component_class.simpleName, equals(#ButtonComponent));
      });

    });

    test('bases components numeration on hashed (time + random) nuber rather than integers if configured', () {
      expect(
        new RegExp('AltNumeration_..+').hasMatch(TemplateStack.templates['altNumeration'].components.values.first.name),
        isTrue
      );
    });

  });

  group('Component', () {

    test('sets component id as a data- attribute to the component\'s html element', () {
      expect(document.querySelectorAll('.captionButton')[0].dataset['componentName'], equals('CaptionButton_1'));
    });
    
    test('replaces content virtual container inside the template html for the contents of its custom element', () {
      expect(document.querySelectorAll('div.button')[0].text, equals('This is button 1 caption'));
    });

    test('puts property values into appropriate virtual containers', () {
      var property_container = new DOMVirtualContainer.find('Component_property:caption', document.querySelector('.captionButton'));
      expect(property_container.text, equals('hello'));
    });

    test('takes values for component properties from custom element data-property- attributes', () {
      expect(TemplateStack.templates['captionButton'].components['CaptionButton_1'].caption, equals('hello'));
    });

    test('builds nested components using appropriate templates', () {
      expect(document.querySelectorAll('.buttonContainer .button').length, equals(2));
    });

    test('changes corresponding element contents in DOM when a field changes', () {
      var property_container = new DOMVirtualContainer.find('Component_property:caption', document.querySelector('.captionButton'));
      TemplateStack.templates['captionButton'].components['CaptionButton_1'].caption = 'new caption';
      expect(property_container.text, equals('new caption'));
    });

    test('notifies parent of the event', () {

      // 1. Trigger a click on a dom element
      document.querySelectorAll('.mock .mock')[0].click();

      // 2. Make sure the component caught the event
      expect(TemplateStack.templates['mock'].components['Mock_2'].mock_calls[0], equals('called captureEvent() with click'));

      // 3. Make sure the parent of the component was also notified of the event
      expect(TemplateStack.templates['mock'].components['Mock_1'].mock_calls[0], equals('called captureEvent() with any.click'));

    });

    test('handles events of DOM elements which the component is composed of', () {
      document.querySelectorAll('.mock .mock .clickableStuff')[0].click();
      expect(TemplateStack.templates['mock'].components['Mock_2'].mock_calls.contains('called captureEvent() with increment_counter'), equals(true));
      expect(TemplateStack.templates['mock'].components['Mock_1'].mock_calls.contains('called captureEvent() with any.increment_counter'), equals(true));
    });

    test('gets assigned a role', () {
      expect(TemplateStack.templates['button'].components['Button_1'].role, equals('stupid'));
    });

    test('puts newly added childrens\' DOM elements into containers based on their role', () {
      var button_container    = TemplateStack.templates['buttonContainer'].components['ButtonContainer_1'];
      var button_without_role = new ButtonComponent.build({});
      var button_with_role    = new ButtonComponent.build({ 'role': 'submit'});
      button_container.addChild(button_without_role);
      button_container.addChild(button_with_role);
      var any_children    = new DOMVirtualContainer.find('Component_children:any',    button_container.element);
      var submit_children = new DOMVirtualContainer.find('Component_children:submit', button_container.element);
      expect(any_children.children[0], equals(button_without_role.element));
      expect(submit_children.children[0], equals(button_with_role.element));
    });

    test('executes a function when adding a new child', () {
      var button_container = TemplateStack.templates['buttonContainer'].components['ButtonContainer_1'];
      var new_button = new ButtonComponent.build({});
      var function_called = false;
      button_container.addChild(new_button, (c) {
        function_called = true;
      });
      expect(function_called, isTrue);
    });

    test('assigns a custom name for the component, does not allow to change it later', () {
      var super_button = TemplateStack.templates['button'].components['SuperButton_1'];
      expect(super_button, isNotNull);
      expect(() => super_button.name = "NewSuperButtonName_1", throwsException);
    });

    test('removes itself from DOM and from the Template\'s components Map', () {
      var button_container = TemplateStack.templates['buttonContainer'].components['ButtonContainer_1'];
      var button_components = TemplateStack.templates['button'].components;
      var new_button = new ButtonComponent.build({ 'name' : 'ButtonToBeRemovedLater_1' });
      button_container.addChild(new_button);
      expect(button_components['ButtonToBeRemovedLater_1'], isNotNull);
      expect(document.querySelector('.button[data-component-name=ButtonToBeRemovedLater_1]'), isNotNull);
      new_button.remove();
      expect(button_components['ButtonToBeRemovedLater_1'], isNull);
      expect(document.querySelector('.button[data-component-name=ButtonToBeRemovedLater_1]'), isNull);
    });

    test('updates content when binded attribute is updated', () {
      // This actually checks the concept, not the core functionality of the Component class.
      // The behavior responsible for this test passing is defined above in this file
      // in a CaptionAsContentButtonComponent class.
      var component = TemplateStack.templates['captionAsContentButton'].components['CaptionAsContentButton_1'];
      var content   = new DOMVirtualContainer.find('Component_content', component.element);
      component.caption = "new content";
      expect(content.text, equals('new content'));
    });


    group('adding and removing children with roles', () {

      var button_container = TemplateStack.templates['buttonContainer'].components['ButtonContainer_1'];
      button_container.addChild(new ButtonComponent.build({ 'role': 'temporary_button'}));
    
      test('finds children with specific roles', () {
        expect(button_container.children('temporary_button').length, equals(1));
        expect((button_container.children().length > 1), isTrue);
        expect((button_container.children('temporary_button')[0] is Component), isTrue);
      });

      test("when removed, removes itself from the parent's, children list", () {
        var button = new ButtonComponent.build({ 'role': 'temporary_button' });
        button_container.addChild(button);
        expect(button_container.children('temporary_button').contains(button), isTrue);
        expect(button_container.children().contains(button), isTrue);
        button.remove();
        expect(button_container.children('temporary_button').contains(button), isFalse);
        expect(button_container.children().contains(button), isFalse);
      });

    });

    test('updates all attributes when subscribing component to the model and then when updating the model', () {
      var button = new ButtonComponent.build({ 'template_name': 'captionButton' });
      expect(button.caption, isNull);
      var model = new DummyModel();
      model.caption = 'caption change 1';
      button.model = model;
      expect(button.caption, equals('caption change 1'));
      expect(new DOMVirtualContainer.find('Component_property:caption', button.element).text, equals('caption change 1'));
      model.caption = 'caption change 2';
      button.captureEvent('model.update', model);
      expect(button.caption, equals('caption change 2'));
      expect(new DOMVirtualContainer.find('Component_property:caption', button.element).text, equals('caption change 2'));
    });

    test('updates attributes in bulk, adds validation errors (Validatable is mixed in)', () {
      var button = new ButtonComponent.build({});
      button.updateAttributes({ 'caption' : 'new caption'});
      expect(button.caption, equals('new caption'));
      var validatable_component = new ValidatableComponent.build({ 'template_name': 'button'});
      expect(validatable_component.updateAttributes({ 'attr1' : 11, 'attr2': ''}), isFalse);
      expect(validatable_component.validation_errors.keys.contains('attr1'), isTrue);
      expect(validatable_component.validation_errors.keys.contains('attr2'), isTrue);
    });
  
  });

  group('string case operations', () {
    test('converts dasherized names int camelcase', () {
      expect(dashedToCamelcase('hello-world'), equals('HelloWorld'));
    });
  });

  test("finds all subclasses", () {
    expect(findSubclasses('Component').length, equals(3)); 
    expect(findSubclasses('Component')[1],     equals(reflectClass(ButtonComponent))); 
  });

}
