import {Component, input} from '@angular/core';

@Component({
  selector: 'my-comp',
  template: '<div></div>',
})
export class MyComponent {
  name = input.required<string>();
}
