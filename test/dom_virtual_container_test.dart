import 'dart:html';
import 'package:unittest/unittest.dart';
import 'package:unittest/mock.dart';
import 'package:unittest/html_config.dart';
import 'dart:mirrors';
import '../component_temple.dart';

main() {

  useHtmlConfiguration();

  group('DOMVirtualContainer', () {

    var button = document.querySelector('.button div');
    var ic     = new DOMVirtualContainer.find('Component_content', button);
    var added_element;

    tearDown(() {
      if(added_element != null) {
        added_element.remove();
        added_element = null;
      }
    });
  
    test('finds invisible container opening comment tag and creates a closing tag for it', () {

      var comment_nodes = [];
      button.childNodes.forEach((n) {
        if(n.nodeType == 8) { comment_nodes.add(n); }
      });
      expect(comment_nodes.length, equals(2));
      expect(comment_nodes[0].nodeValue, equals('Component_content'));
      expect(comment_nodes[1].nodeValue, equals('END-OF-Component_content'));

    });


    test('adds child element to the bottom', () {
      ic.prepend(new Element.html("<div id='child1'></div>"));
      added_element = button.querySelector('div#child1');
      expect(added_element, isNotNull);
      expect(added_element.previousNode.nodeValue, equals('Component_content'));
    });

    test('adds child element to the top', () {
      ic.append(new Element.html("<div id='child2'></div>"));
      added_element = button.querySelector('div#child2');
      expect(added_element, isNotNull);
      expect(added_element.nextNode.nodeValue, equals('END-OF-Component_content'));
    });

    test('gets a list of children', () {
      ic.append(new Element.html("<div id='child3'></div>"));
      ic.append(new Element.html("<div id='child4'></div>"));
      expect(ic.children.length, equals(2));

      //cleaning up
      ic.children.forEach((c) => c.remove());
    });

    test('finds multiple invisible containers with names specified by a regexp', () {
      var button2    = document.querySelector('.button2 div');
      var containers = new DOMVirtualContainer.findAll('Component_property.*', button2);
      expect(containers.length, equals(2));
      containers.forEach((c) => expect(c is DOMVirtualContainer, isTrue));
      containers = new DOMVirtualContainer.findAll('Component_property:loc.*', button2);
      expect(containers.length, equals(1));
    });


    // This is useful when we, for example, do not wish to look inside the virtual cotainers
    // of the children components.
    test('stops looking into child nodes if the node qualifies as a stop point', () {
      var parent     = document.querySelector('.parent');
      var containers = new DOMVirtualContainer.findAll('Component_property.*', parent, skip_children: ['data-component-name']);
      expect(containers.length, equals(1));
    });

    test('sets text value for itself', () {
      ic.text = 'new caption';
      expect(ic.children[0].text, equals('new caption'));
    });

  });

}
