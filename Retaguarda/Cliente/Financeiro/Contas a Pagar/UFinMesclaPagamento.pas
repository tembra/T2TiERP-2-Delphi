{ *******************************************************************************
Title: T2Ti ERP
Description: Janela para Mesclar Lan�amentos

The MIT License

Copyright: Copyright (C) 2016 T2Ti.COM

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

The author may be contacted at:
t2ti.com@gmail.com</p>

@author Albert Eije
@version 2.0
******************************************************************************* }
unit UFinMesclaPagamento;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms, Atributos,
  Dialogs, UTelaCadastro, DB, DBClient, Menus, StdCtrls, ExtCtrls, Buttons, Grids,
  DBGrids, JvExDBGrids, JvDBGrid, JvDBUltimGrid, ComCtrls, ViewFinLancamentoPagarVO,
  ViewFinLancamentoPagarController, Tipos, Constantes, LabeledCtrls,
  ActnList, RibbonSilverStyleActnCtrls, ActnMan, Mask, JvExMask, JvToolEdit,
  JvExStdCtrls, JvEdit, JvValidateEdit, ToolWin, ActnCtrls, JvBaseEdits,
  Generics.Collections, Biblioteca, RTTI, FinChequeEmitidoVO, AdmParametroVO,
  System.Actions, Controller;

type
  [TFormDescription(TConstantes.MODULO_CONTAS_PAGAR, 'Mescla Pagamento')]

  TFFinMesclaPagamento = class(TFTelaCadastro)
    BevelEdits: TBevel;
    PanelMestre: TPanel;
    EditIdFornecedor: TLabeledCalcEdit;
    EditFornecedor: TLabeledEdit;
    EditIdDocumentoOrigem: TLabeledCalcEdit;
    EditDocumentoOrigem: TLabeledEdit;
    ComboBoxPagamentoCompartilhado: TLabeledComboBox;
    EditImagemDocumento: TLabeledEdit;
    EditPrimeiroVencimento: TLabeledDateEdit;
    EditQuantidadeParcelas: TLabeledCalcEdit;
    EditValorAPagar: TLabeledCalcEdit;
    EditValorTotal: TLabeledCalcEdit;
    EditDataLancamento: TLabeledDateEdit;
    EditNumeroDocumento: TLabeledEdit;
    EditIntervalorEntreParcelas: TLabeledCalcEdit;
    PageControlItensLancamento: TPageControl;
    tsLancamentos: TTabSheet;
    PanelItensLancamento: TPanel;
    GridItens: TJvDBUltimGrid;
    PanelTotais: TPanel;
    DSLancamentoSelecionado: TDataSource;
    CDSLancamentoSelecionado: TClientDataSet;
    procedure FormCreate(Sender: TObject);
    procedure CalcularTotais;
    procedure GridCellClick(Column: TColumn);
    procedure GridDrawColumnCell(Sender: TObject; const Rect: TRect; DataCol: Integer; Column: TColumn; State: TGridDrawState);
    procedure EditIdFornecedorKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure EditIdDocumentoOrigemKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
  private
    { Private declarations }
  public
    { Public declarations }
    procedure ControlaBotoes; override;
    procedure ControlaPopupMenu; override;

    // Controles CRUD
    function DoEditar: Boolean; override;
  end;

var
  FFinMesclaPagamento: TFFinMesclaPagamento;
  ChequeEmitido: TFinChequeEmitidoVO;
  SomaCheque: Extended;
  AdmParametroVO: TAdmParametroVO;

implementation

uses
  FinLancamentoPagarVO, FinLancamentoPagarController, FinParcelaPagarVO,
  FinParcelaPagarController, FinTipoPagamentoVO, FinTipoPagamentoController,
  ContaCaixaVO, ContaCaixaController, UTela, USelecionaCheque, UDataModule,
  AdmParametroController, FinDocumentoOrigemVO, FinDocumentoOrigemController,
  ViewPessoaFornecedorVO, ViewPessoaFornecedorController;

{$R *.dfm}

{$REGION 'Infra'}
procedure TFFinMesclaPagamento.FormCreate(Sender: TObject);
var
  Filtro: String;
begin
  ClasseObjetoGridVO := TFinLancamentoPagarVO;
  ObjetoController := TFinLancamentoPagarController.Create;

  inherited;

  // Configura a Grid dos itens
  ConfiguraCDSFromVO(CDSLancamentoSelecionado, TViewFinLancamentoPagarVO);
  ConfiguraGridFromVO(GridItens, TViewFinLancamentoPagarVO);
end;

procedure TFFinMesclaPagamento.ControlaBotoes;
begin
  inherited;

  BotaoInserir.Visible := False;
  BotaoExcluir.Visible := False;
  BotaoAlterar.Caption := 'Mesclar [F3]';
end;

procedure TFFinMesclaPagamento.ControlaPopupMenu;
begin
  inherited;

  MenuInserir.Visible := False;
  MenuExcluir.Visible := False;
  MenuAlterar.Caption := 'Mesclar [F3]';
end;
{$ENDREGION}

{$REGION 'Controles CRUD'}
function TFFinMesclaPagamento.DoEditar: Boolean;
var
  Contador: Integer;
  Filtro, FiltroIN: String;
begin
  Contador := 0;

  if not CDSGrid.IsEmpty then
  begin

    CDSGrid.DisableControls;
    CDSGrid.First;
    while not CDSGrid.Eof do
    begin
      if CDSGrid.FieldByName('MesclarPagamento').AsString = 'S' then
      begin
        Inc(Contador);

        if Contador = 1 then
          FiltroIN := '(' + CDSGrid.FieldByName('ID').AsString
        else
          FiltroIN := FiltroIN + ',' + CDSGrid.FieldByName('ID').AsString;
      end;
      CDSGrid.Next;
    end;
    CDSGrid.First;
    CDSGrid.EnableControls;

    if Contador <= 1 then
    begin
      Application.MessageBox('� preciso selecionar mais do que UM lan�amento para realizar a mesclagem.', 'Mensagem do Sistema', MB_OK + MB_ICONINFORMATION);
      Exit;
    end;

    FiltroIN := FiltroIN + ')';

    TViewFinLancamentoPagarController.SetDataSet(CDSLancamentoSelecionado);
    Filtro := 'ID_LANCAMENTO_PAGAR in ' + FiltroIN;
    TController.ExecutarMetodo('ViewFinLancamentoPagarController.TViewFinLancamentoPagarController', 'Consulta', [Filtro, '0', False], 'GET', 'Lista');

    CalcularTotais;

    Result := inherited DoEditar;

    if Result then
    begin
      EditIdFornecedor.SetFocus;
    end;

  end;
end;
{$ENDREGION}

{$REGION 'Campos Transientes'}
procedure TFFinMesclaPagamento.EditIdFornecedorKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  Filtro: String;
begin
  if Key = VK_F1 then
  begin
    if EditIdFornecedor.Value <> 0 then
      Filtro := 'ID = ' + EditIdFornecedor.Text
    else
      Filtro := 'ID=0';

    try
      EditIdFornecedor.Clear;
      EditFornecedor.Clear;
      if not PopulaCamposTransientes(Filtro, TViewPessoaFornecedorVO, TViewPessoaFornecedorController) then
        PopulaCamposTransientesLookup(TViewPessoaFornecedorVO, TViewPessoaFornecedorController);
      if CDSTransiente.RecordCount > 0 then
      begin
        EditIdFornecedor.Text := CDSTransiente.FieldByName('ID').AsString;
        EditFornecedor.Text := CDSTransiente.FieldByName('NOME').AsString;
      end
      else
      begin
        Exit;
        EditIdDocumentoOrigem.SetFocus;
      end;
    finally
      CDSTransiente.Close;
    end;
  end;
end;


procedure TFFinMesclaPagamento.EditIdDocumentoOrigemKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  Filtro: String;
begin
  if Key = VK_F1 then
  begin
    if EditIdDocumentoOrigem.Value <> 0 then
      Filtro := 'ID = ' + EditIdDocumentoOrigem.Text
    else
      Filtro := 'ID=0';

    try
      EditIdDocumentoOrigem.Clear;
      EditDocumentoOrigem.Clear;
      if not PopulaCamposTransientes(Filtro, TFinDocumentoOrigemVO, TFinDocumentoOrigemController) then
        PopulaCamposTransientesLookup(TFinDocumentoOrigemVO, TFinDocumentoOrigemController);
      if CDSTransiente.RecordCount > 0 then
      begin
        EditIdDocumentoOrigem.Text := CDSTransiente.FieldByName('ID').AsString;
        EditDocumentoOrigem.Text := CDSTransiente.FieldByName('SIGLA_DOCUMENTO').AsString;
      end
      else
      begin
        Exit;
        EditNumeroDocumento.SetFocus;
      end;
    finally
      CDSTransiente.Close;
    end;
  end;
end;
{$ENDREGION}

{$REGION 'Controle de Grid'}
procedure TFFinMesclaPagamento.GridCellClick(Column: TColumn);
begin
  if Column.Index = 0 then
  begin
    if CDSGrid.FieldByName('MESCLADO_PARA').AsInteger > 0 then
    begin
      Application.MessageBox('Procedimento n�o permitido. Lan�amento j� mesclado.', 'Mensagem do Sistema', MB_OK + MB_ICONINFORMATION);
      Exit;
    end;

    CDSGrid.Edit;
    if CDSGrid.FieldByName('MesclarPagamento').AsString = '' then
      CDSGrid.FieldByName('MesclarPagamento').AsString := 'S'
    else
      CDSGrid.FieldByName('MesclarPagamento').AsString := '';
    CDSGrid.Post;
  end;
end;

procedure TFFinMesclaPagamento.GridDrawColumnCell(Sender: TObject; const Rect: TRect; DataCol: Integer; Column: TColumn; State: TGridDrawState);
var
  lIcone : TBitmap;
  lRect: TRect;
begin
  lRect := Rect;
  lIcone := TBitmap.Create;

  if Column.Index = 0 then
  begin
    if Grid.Columns[0].Width <> 32 then
      Grid.Columns[0].Width := 32;

    try
      if Grid.Columns[1].Field.Value = '' then
      begin
        FDataModule.ImagensCheck.GetBitmap(0, lIcone);
        Grid.Canvas.Draw(Rect.Left+8 ,Rect.Top+1, lIcone);
      end
      else if Grid.Columns[1].Field.Value = 'S' then
      begin
        FDataModule.ImagensCheck.GetBitmap(1, lIcone);
        Grid.Canvas.Draw(Rect.Left+8,Rect.Top+1, lIcone);
      end
    finally
      lIcone.Free;
    end;
  end;
end;

{$ENDREGION}

{$REGION 'Actions'}
procedure TFFinMesclaPagamento.CalcularTotais;
var
  Juro, Multa, Desconto, Total, Saldo: Extended;
begin

  /// EXERCICIO: VERIFIQUE SE H� A NECESSIDADE DE EXIBIR OS TOTAIS. CORRIJA O QUE FOR NECESS�RIO NO PROCEDIMENTO E/OU NA VIEW.
  /// EXERCICIO: LEVE EM CONTA NO CALCULO AS PARCELAS JA QUITADAS.

  Juro := 0;
  Multa := 0;
  Desconto := 0;
  Total := 0;
  Saldo := 0;
  //
  CDSLancamentoSelecionado.DisableControls;
  CDSLancamentoSelecionado.First;
  while not CDSLancamentoSelecionado.Eof do
  begin
    Juro := Juro + CDSLancamentoSelecionado.FieldByName('VALOR_JURO').AsExtended;
    Multa := Multa + CDSLancamentoSelecionado.FieldByName('VALOR_MULTA').AsExtended;
    Desconto := Desconto + CDSLancamentoSelecionado.FieldByName('VALOR_DESCONTO').AsExtended;
    Total := Total + CDSLancamentoSelecionado.FieldByName('VALOR_PARCELA').AsExtended;
    CDSLancamentoSelecionado.Next;
  end;
  CDSLancamentoSelecionado.First;
  CDSLancamentoSelecionado.EnableControls;
  //
  PanelTotais.Caption := '|      Juros: ' +  FloatToStrF(Juro, ffCurrency, 15, 2) +
                        '      |      Multa: ' +   FloatToStrF(Multa, ffCurrency, 15, 2) +
                        '      |      Desconto: ' +   FloatToStrF(Desconto, ffCurrency, 15, 2) +
                        '      |      Total Parcelas: ' +   FloatToStrF(Total, ffCurrency, 15, 2) +
                        '      |      Saldo: ' +   FloatToStrF(Total - EditValorAPagar.Value, ffCurrency, 15, 2) + '      |';
end;
{$ENDREGION}

/// EXERCICIO: IMPLEMENTE A PERSISTENCIA DA NOVA PARCELA MESCLADA
/// EXERCICIO: ARMAZENE NO CAMPO MESCLADO_PARA O ID DO NOVO LAN�AMENTO GERADO PARA VINCULAR O HISTORICO DOS LAN�AMENTOS
/// EXERCICIO: DESENHE A JANELA DA MELHOR FORMA POSS�VEL PARA O USU�RIO

end.
