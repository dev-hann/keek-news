import { Children, Fragment, type ReactNode } from 'react';
import { Separator } from '../components/ui/separator';

interface SettingsGroupProps {
  title: string;
  children: ReactNode;
}

/** Setting rows of one kind, on one surface, with a title above them. */
export function SettingsGroup({ title, children }: SettingsGroupProps) {
  return (
    <section className="px-4 py-2">
      <h2 className="pb-2 pl-1 text-base font-semibold">{title}</h2>
      <div className="overflow-hidden rounded-xl bg-card ring-1 ring-foreground/10">
        {Children.toArray(children).map((child, index) => (
          <Fragment key={index}>
            {index > 0 && <Separator />}
            {child}
          </Fragment>
        ))}
      </div>
    </section>
  );
}
