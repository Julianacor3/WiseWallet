import 'package:flutter/material.dart';

class PaymentMethodsScreen extends StatelessWidget {
  const PaymentMethodsScreen({super.key});

  static const Color primaryColor = Color(0xFF7569B5);

  final List<Map<String, dynamic>> methods = const [
    {
      'title': 'Efectivo',
      'subtitle': 'Pagos realizados directamente con dinero físico.',
      'icon': Icons.payments_outlined,
      'color': Colors.green,
      'advantages': [
        'No requiere conexión a internet.',
        'Es aceptado en muchos establecimientos.',
        'Permite controlar fácilmente los gastos pequeños.',
      ],
      'recommendation': 'Lleva únicamente el efectivo necesario y guarda el dinero en un lugar seguro.',
    },
    {
      'title': 'Tarjeta débito',
      'subtitle': 'Permite pagar utilizando el dinero disponible en tu cuenta bancaria.',
      'icon': Icons.credit_card,
      'color': Colors.blue,
      'advantages': [
        'El dinero se descuenta directamente de tu cuenta.',
        'Facilita el seguimiento de los movimientos.',
        'Permite realizar compras físicas y en línea.',
      ],
      'recommendation': 'Nunca compartas tu clave o PIN y activa las notificaciones de tus movimientos.',
    },
    {
      'title': 'Tarjeta crédito',
      'subtitle':
          'Permite realizar compras utilizando un cupo de crédito aprobado.',
      'icon': Icons.credit_score_outlined,
      'color': Colors.deepPurple,
      'advantages': [
        'Permite financiar compras.',
        'Puede ofrecer beneficios y recompensas.',
        'Facilita las compras por internet.',
      ],
      'recommendation': 'Paga a tiempo tus cuotas y revisa las tasas de interés antes de financiar una compra.',
    },
    {
      'title': 'Transferencia bancaria',
      'subtitle': 'Permite enviar dinero entre cuentas bancarias.',
      'icon': Icons.account_balance_outlined,
      'color': Colors.orange,
      'advantages': [
        'Permite transferir dinero sin utilizar efectivo.',
        'Facilita los pagos entre personas.',
        'Deja un comprobante de la operación.',
      ],
      'recommendation': 'Verifica cuidadosamente el número de cuenta y el destinatario antes de confirmar.',
    },
    {
      'title': 'Billeteras digitales',
      'subtitle': 'Aplicaciones que permiten almacenar y transferir dinero digitalmente.',
      'icon': Icons.account_balance_wallet_outlined,
      'color': Colors.teal,
      'advantages': [
        'Permiten realizar pagos desde el celular.',
        'Facilitan las transferencias.',
        'Pueden ofrecer pagos mediante códigos QR.',
      ],
      'recommendation': 'Utiliza contraseñas seguras, activa la verificación en dos pasos y evita enlaces sospechosos.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Medios de pago',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFD5D2F0),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Conoce tus opciones',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Existen diferentes formas de realizar pagos. '
            'Conocer sus características te ayudará a tomar '
            'mejores decisiones financieras.',
            style: TextStyle(fontSize: 15, color: Colors.black54),
          ),
          const SizedBox(height: 22),

          ...methods.map((method) {
            final Color methodColor = method['color'] as Color;
            final List<String> advantages = (method['advantages'] as List)
                .cast<String>();

            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: CircleAvatar(
                  radius: 25,
                  backgroundColor: methodColor.withValues(alpha: 0.12),
                  child: Icon(
                    method['icon'] as IconData,
                    color: methodColor,
                    size: 27,
                  ),
                ),
                title: Text(
                  method['title'] as String,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    method['subtitle'] as String,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                children: [
                  const Divider(),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Características y ventajas',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...advantages.map(
                    (advantage) => Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 18,
                            color: methodColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              advantage,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0EEFA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.security, color: primaryColor, size: 19),
                            SizedBox(width: 7),
                            Text(
                              'Recomendación de seguridad',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Text(
                          method['recommendation'] as String,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 5),
          const Card(
            color: Color(0xFFEAE7F8),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline, color: primaryColor, size: 25),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Consejo Wise Wallet: antes de elegir un medio de pago, '
                      'considera tu presupuesto, la seguridad de la operación '
                      'y los posibles costos asociados.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
