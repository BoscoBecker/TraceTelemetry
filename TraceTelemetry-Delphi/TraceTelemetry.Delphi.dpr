package TraceTelemetry.Delphi;

{$R *.res}
{$ALIGN 8}
{$ASSERTIONS ON}
{$BOOLEVAL OFF}
{$DEBUGINFO ON}
{$EXTENDEDSYNTAX ON}
{$IMPORTEDDATA ON}
{$IOCHECKS ON}
{$LOCALSYMBOLS ON}
{$LONGSTRINGS ON}
{$OPENSTRINGS ON}
{$OPTIMIZATION ON}
{$OVERFLOWCHECKS OFF}
{$RANGECHECKS OFF}
{$REFERENCEINFO ON}
{$SAFEDIVIDE OFF}
{$STACKFRAMES OFF}
{$TYPEDADDRESS OFF}
{$VARSTRINGCHECKS ON}
{$WRITEABLECONST OFF}
{$MINENUMSIZE 1}
{$IMAGEBASE $400000}
{$DESCRIPTION 'TraceTelemetry SDK for Delphi'}
{$LIBSUFFIX '170'}
{$LIBVERSION '1.0.0.0'}
{$RUNONLY}
{$IMPLICITBUILD OFF}

requires
  rtl;

contains
  TraceTelemetry.Options in 'Source\TraceTelemetry.Options.pas',
  TraceTelemetry.Models in 'Source\TraceTelemetry.Models.pas',
  TraceTelemetry.Queue in 'Source\TraceTelemetry.Queue.pas',
  TraceTelemetry.Transport in 'Source\TraceTelemetry.Transport.pas',
  TraceTelemetry.Client in 'Source\TraceTelemetry.Client.pas';

end.
